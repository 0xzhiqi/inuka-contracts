// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;


import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IInukaPartnerToken {
    // function getOnChainVerifyStatus (uint256 _projectId) external view returns (AuditStatus _statusDerived)
}

contract InukaPlasticCredit is ERC1155, Ownable {

    struct Project {
        address projectOwner;
        bytes32 projectName;
        bytes32 location;
        bytes32 polymerType;
        bytes32 plasticForm;
    }

    enum AuditStatus { None, Partial, Complete}

    mapping (uint256 => Project) private projectIdentifier; // TODO: Change to private?
    mapping (uint256 => bool) private projectFinalised;
    mapping (uint256 => AuditStatus) private auditStatus;

    string public name;
    string public symbol;
    uint256 private _projectTokenId;


    // TODO: Add events here

    // Add event for project created


    // TODO: Add modifiers here
    modifier onlyProjectCreator(uint256 _projectId) {
        require(projectIdentifier[_projectId].projectOwner == msg.sender, "Not project creator");
        _;
    }

    modifier projectIsFinalised(uint256 _projectId) {
        require(projectFinalised[_projectId] == false, "Project finalised");
        _;
    }

    constructor() ERC1155("") {
        name = "Inuka Plastic Credit";
        symbol = "IPC";
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /**
    * @dev To consider adding payable and fees via modifier to create a project i.e. minting fee
    */
    function createProject(
        bytes32 _projectName, 
        bytes32 _location,
        bytes32 _polymerType,
        bytes32 _plasticForm
    ) external {
        _projectTokenId ++;
        projectIdentifier[_projectTokenId] = 
        Project({
            projectOwner: msg.sender, 
            projectName: _projectName,
            location: _location,
            polymerType: _polymerType,
            plasticForm: _plasticForm
        });

        // TODO: Link to INC campaign contract
    }

    function createPlasticCredit(
        uint256 _projectId, 
        uint256 _amount
    ) external 
    onlyProjectCreator (_projectId)
    projectIsFinalised (_projectId) {
        _mint(msg.sender, _projectId, _amount, "");
    }

    function finaliseProject (uint256 _projectId) external onlyProjectCreator (_projectId) {
        projectFinalised[_projectId] = true;
    }

    function getProject(uint256 _projectId) public view returns (Project memory projectFound) {
        projectFound = projectIdentifier[_projectId];
    }

    function getProjectFinality(uint256 _projectId) public view returns (bool projectFinalisedFound) {
        projectFinalisedFound = projectFinalised[_projectId];
    }

}