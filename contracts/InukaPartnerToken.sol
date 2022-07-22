// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

interface IInukaPlasticCredit {
    // modifier onlyProjectCreator (uint256 _projectId);
    struct Project {
        address projectOwner;
        bytes32 projectName;
        bytes32 location;
        bytes32 polymerType;
        bytes32 plasticForm;
    }
    // enum AuditStatus { None, Partial, Complete}

    function getProject(uint256 _projectId) external view returns (Project memory _project);
}

interface IIPCMarketplace {
    function getPercentRedeemed (address _holder) external view returns (uint256 percentRedeemedFound);
}

interface IIPTLaunchpad {
    struct PrimaryListingDetail {
        address lister;
        uint256 price;
        uint256 amount;
        bool active;
        uint256 fundraiseEnds;
        uint256 projectStarts;
        uint256 phasesCount;
        uint256[] phasesDate;
        uint256[] phasesFund;
    }
    function getPrimaryListingFeed (uint256 _projectId) external view returns (PrimaryListingDetail memory detail);
}

interface IIPTPoll {
    function getLatestPollDeadline (uint256 _projectId) external view returns (uint256 deadline);
}

// TODO: Consider removing Ownable

contract InukaPartnerToken is ERC1155, Ownable {
    struct Audit {
        bytes32 claim;
        bytes32 evidence;
        address auditor;
        bool onChainVerified; // can only be updated by nominated auditor
    }

    enum AuditStatus { None, Partial, Complete}
    mapping (uint256 => Audit[]) private _auditTrail;
    mapping (uint256 => uint256) private _mintedAmount;
    mapping (uint256 => bool) private _mintDeactivated;

    bool batchTransferActive;

    address private IPTMarketplaceAddress;

    string public name;
    string public symbol;
    uint256 private _projectTokenId;

    IInukaPlasticCredit private inukaPlasticCredit;
    IIPCMarketplace private iPCMarketplace;
    IIPTLaunchpad private iPTLaunchpad;
    IIPTPoll private iPTPoll;

    // TODO: Add events here

    // TODO: Add modifiers here

    modifier onlyProjectCreator(uint256 _projectId) {
        address projectOwner = inukaPlasticCredit.getProject(_projectId).projectOwner;
        require(projectOwner == msg.sender, "Not project creator");
        _;
    }

    modifier canBatchTransfer () {
        require(batchTransferActive, "Inactive");
        _;
    }

    constructor(address _inukaPlasticCreditAddress) ERC1155("") {
        name = "Inuka Partner Token";
        symbol = "IPT";
        inukaPlasticCredit = IInukaPlasticCredit(_inukaPlasticCreditAddress);
    }

    function setIPCMarketplace(address _iPCMarketplace) external onlyOwner {
        iPCMarketplace = IIPCMarketplace(_iPCMarketplace);
    }

    function setIPTPoll(address _iPTPoll) external onlyOwner {
        iPTPoll = IIPTPoll(_iPTPoll);
    }

    function setIPTLaunchpad(address _iPTLaunchpad) external onlyOwner {
        iPTLaunchpad = IIPTLaunchpad(_iPTLaunchpad);
    }

    function createToken (uint256 _amount, uint256 _projectId) external onlyProjectCreator(_projectId) {
        _mint(msg.sender, _projectId, _amount, "");
    }

    function updateAuditTrail (
        uint256 _projectId, 
        bytes32 _claim,
        bytes32 _evidence,
        address _auditor
    ) external onlyProjectCreator(_projectId) {
        // TODO: Check that auditor address is valid
        _auditTrail[_projectId].push(Audit({
            claim: _claim,
            evidence: _evidence,
            auditor: _auditor,
            onChainVerified: false
        }));
    }

    function onChainVerify (uint256 _projectId, uint256 _index) public {
        // TODO: Check if default address is address(0) and if first require is even necessary
        require(inukaPlasticCredit.getProject(_projectId).projectOwner != address(0), "No Project");
        require(_index <= _auditTrail[_projectId].length, "No audit");
        require(_auditTrail[_projectId][_index].auditor == msg.sender, "Not auditor");
        _auditTrail[_projectId][_index].onChainVerified = true;
    }

    function getOnChainVerifyStatus (uint256 _projectId) external view returns (AuditStatus _statusDerived) {
        // TODO: Need to check if _projectId exists?
        uint256 auditTrailLength = _auditTrail[_projectId].length;
        uint256 index;
        uint256 verify;
        while (index < auditTrailLength) {
            if (_auditTrail[_projectId][index].onChainVerified == true) {
                verify++;
            }
            index++;
        }
        if (verify == 0) {
            _statusDerived = AuditStatus.None; // 0
        } else if (verify == auditTrailLength) {
            _statusDerived = AuditStatus.Complete; //2
        } else {
            _statusDerived = AuditStatus.Partial; // 1
        }
    } 

    function getAuditStatus (uint256 _projectId, uint256 _index) external view returns (Audit memory _auditFound) {
        // TODO: Revert if index is missing
        _auditFound = _auditTrail[_projectId][_index];
    }

    // Temp function
    function getAuditTrailLength (uint256 _projectId) external view returns (uint256 length) {
        length = _auditTrail[_projectId].length;
    }

    // TODO: Add Override safeTransferFrom
    // 2 cases when tokens cannot be transferred:
    // 1: when poll is active
    // 2: when redemption has been made
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(iPTLaunchpad.getPrimaryListingFeed(id).fundraiseEnds < block.timestamp, "Fundraising active");
        require(iPTPoll.getLatestPollDeadline(id) < block.timestamp, "Poll active");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
    /* @dev Batch transfer deactivated as it is not used in both Inuka marketplaces
    */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override canBatchTransfer {
        require(false, "No batch transfer");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // TODO: Consider if anything needs to be done to: and approve functions and/or before transfer function

    function getMintedAmount (uint256 _projectId) external view returns (uint256 mintedAmountFound) {
        mintedAmountFound = _mintedAmount[_projectId];
    }

    function setIPTMarketplaceAddress (address _address) external onlyOwner {
        IPTMarketplaceAddress = _address;
    }

    // TODO: test that require statement works
    function deactivateMint (uint256 _projectId) external {
        require(msg.sender == IPTMarketplaceAddress, "Unauthorised");
        _mintDeactivated[_projectId] = true;
    }

    // TODO: test that require statement works
    function undoDeactivateMint (uint256 _projectId) external {
        require(msg.sender == IPTMarketplaceAddress, "Unauthorised");
        _mintDeactivated[_projectId] = false;
    }
}