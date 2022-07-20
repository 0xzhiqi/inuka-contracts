// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// Import this file to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InukaPlasticCredit is ERC1155, Ownable {

    struct Audit {
        bytes32 claim;
        bytes32 evidence;
        address auditor;
        bool onChainVerified; // can only be updated by nominated auditor
    }

    struct Project {
        address projectOwner;
        bytes32 projectName;
        bytes32 location;
        bytes32 polymerType;
        bytes32 plasticForm;
        Audit[] auditTrail;
    }

    mapping (uint256 => address) public projectOwner;

    string public name;
    string public symbol;
    uint256 private _tokenId;

    // TODO: Add events here


    // TODO: Add modifiers here


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
        
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }
}