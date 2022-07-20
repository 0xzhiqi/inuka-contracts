// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IInukaPlasticCredit {
    // modifier onlyProjectCreator (uint256 _projectId);
    struct Project {
        address projectOwner;
        bytes32 projectName;
        bytes32 location;
        bytes32 polymerType;
        bytes32 plasticForm;
    }

    function getProject(uint256 _projectId) external view returns (Project memory _project);
}

// TODO: Consider removing Ownable

contract InukaPartnerToken is ERC1155, Ownable {
    struct Audit {
        bytes32 claim;
        bytes32 evidence;
        address auditor;
        bool onChainVerified; // can only be updated by nominated auditor
    }

    mapping (uint256 => Audit[]) private _auditTrail;

    string public name;
    string public symbol;
    uint256 private _projectTokenId;

    IInukaPlasticCredit private inukaPlasticCredit;

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

    function createToken (uint256 _amount, uint256 _projectId) external onlyProjectCreator(_projectId) {
        // inukaPlasticCredit.getProject(_projectId).projectOwner;
            _mint(msg.sender, _projectId, _amount, "");

    }

}