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

interface IInukaPlasticCreditMarketplace {
    function getPercentRedeemed (address _holder) external view returns (uint256 percentRedeemedFound);
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

    string public name;
    string public symbol;
    uint256 private _projectTokenId;

    IInukaPlasticCredit private inukaPlasticCredit;
    IInukaPlasticCreditMarketplace private inukaPlasticCreditMarketplace;

    // TODO: Add events here

    // TODO: Add modifiers here

    modifier onlyProjectCreator(uint256 _projectId) {
        address projectOwner = inukaPlasticCredit.getProject(_projectId).projectOwner;
        require(projectOwner == msg.sender, "Not project creator");
        _;
    }

    constructor(address _inukaPlasticCreditAddress) ERC1155("") {
        name = "Inuka Partner Token";
        symbol = "IPT";
        inukaPlasticCredit = IInukaPlasticCredit(_inukaPlasticCreditAddress);
    }

    function setInukaPlasticCreditMarketplace (address _InukaPlasticCreditMarketplace) external onlyOwner {
        inukaPlasticCreditMarketplace = IInukaPlasticCreditMarketplace(_InukaPlasticCreditMarketplace);
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

    // TODO: Add Override safeTransferFrom, safeBatchTransferFrom and approve functions and/or before transfer function
}