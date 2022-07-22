// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IMockUsdc {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IInukaPlasticCredit {
    // modifier onlyProjectCreator (uint256 _projectId);
    struct Project {
        address projectOwner;
        bytes32 projectName;
        bytes32 location;
        bytes32 polymerType;
        bytes32 plasticForm;
    }
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function setApprovalForAll(address operator, bool approved) external;
    function getProject(uint256 _projectId) external view returns (Project memory _project);
}

interface IInukaPartnerToken {
    function getMintedAmount (uint256 _projectId) external view returns (uint256 mintedAmountFound);
    function deactivateMint (uint256 _projectId) external;
    function undoDeactivateMint (uint256 _projectId) external;
}

error IPTMarketplace__BuyTokenArrayLengthMismatch(
    uint256 tokenId, 
    uint256 index,
    uint256 price,
    uint256 amount,
    uint256 array
);

error IPTMarketplace__InsufficientBalance(
    uint256 balance,
    uint256 required
);

error IPTMarketplace__ (

);

contract IPTMarketplace is Ownable {
    IMockUsdc public mockUsdc;
    IInukaPlasticCredit private inukaPlasticCredit;
    IInukaPartnerToken private inukaPartnerToken;

    struct SecondaryListingDetail {
        address lister;
        uint256 price;
        uint256 amount;
        bool active;
    }

    /**
    /* @notice Tracks for each tokenId a strictly increasing index on total number of listings,
    /* both active and inactive
    */
    mapping(uint256 => uint256) private secondarylistingIndexTracker;
    /**
    /* @notice For each tokenId maps the index from secondarylistingIndexTracker to SecondaryListingDetail
    */
    mapping (uint256 => mapping (uint256 => SecondaryListingDetail)) private secondaryListingFeed;
    /**
    /* @notice Tracks for each projectId how much each wallet has funded it
    /* @dev To reconsider if this is necessary, or we can derive this value directly from wallet balance and price
    */

    // TODO: Add events here

    // Add modifiers here

    modifier onlyProjectCreator(uint256 _projectId) {
        address projectOwner = inukaPlasticCredit.getProject(_projectId).projectOwner;
        require(projectOwner == msg.sender, "Not project creator");
        _;
    }

    function setMockUsdc (address _mockUsdcAddress) external onlyOwner {
        mockUsdc = IMockUsdc(_mockUsdcAddress);
    }

    function setInukaPlasticCredit (address _inukaPlasticCreditAddress) external onlyOwner {
        inukaPlasticCredit = IInukaPlasticCredit(_inukaPlasticCreditAddress);
    }

    function setInukaPartnerToken (address _inukaPartnerTokenAddress) external onlyOwner {
        inukaPartnerToken = IInukaPartnerToken(_inukaPartnerTokenAddress);
    }

    function listSecondaryToken (
        uint256 _projectId, 
        uint256 _price, 
        uint256 _amount
        ) external 
        onlyProjectCreator(_projectId) 
    {
        require(inukaPlasticCredit.balanceOf(msg.sender, _projectId) >= _amount, "Insufficient balance");
        require(_price > 0, "No price");
        inukaPlasticCredit.setApprovalForAll(address(this), true);
        secondarylistingIndexTracker[_projectId]++;
        _setSecondaryListingDetail(_projectId, secondarylistingIndexTracker[_projectId], msg.sender, _price, _amount);
    }

    function delistSecondaryToken () external {}

    /**
    /* @dev From the frontend, for 2 listings with the same price, the listing that was put up first 
    /* will be sold first i.e. FIFO
    */
    function buySecondaryToken (
        uint256[] calldata _projectId, 
        uint256[] calldata _index, 
        uint256[] calldata _price, 
        uint256[] calldata _amount,
        uint256 _arrayLength
        ) external {
            // TODO: Check if gas can be optimised with separate error statements
            if (
                _projectId.length != _arrayLength || 
                _index.length != _arrayLength || 
                _price.length != _arrayLength || 
                _amount.length != _arrayLength 
            ) {
                revert IPTMarketplace__BuyTokenArrayLengthMismatch({
                    tokenId: _projectId.length,  
                    index: _index.length,
                    price: _price.length,
                    amount: _amount.length,
                    array: _arrayLength
                });
            }
            // TODO: Check if saving mockUsdc.balanceOf(msg.sender) as a variable saves gas
            uint256 totalPrice; // TODO: fill this in
            if (mockUsdc.balanceOf(msg.sender) < totalPrice) {
                revert IPTMarketplace__InsufficientBalance({
                    balance: mockUsdc.balanceOf(msg.sender),
                    required: totalPrice
                });
            }
            mockUsdc.transferFrom(msg.sender, address(this), totalPrice);
    }
    
    function getSecondaryPrice (uint256 _projectId, uint256 _index) public view returns (uint256 priceFound){
        priceFound = secondaryListingFeed[_projectId][_index].price;
    }

    // to add complementary functions - track address of listers
    /**
    /* Used in listToken function
    */
    function _setSecondaryListingDetail (
        uint256 _projectId, 
        uint256 _index,
        address _lister,
        uint256 _price,
        uint256 _amount
        ) private {
        secondaryListingFeed[_projectId][_index].lister = _lister;
        secondaryListingFeed[_projectId][_index].price = _price;
        secondaryListingFeed[_projectId][_index].amount = _amount;
        secondaryListingFeed[_projectId][_index].active = true;
    }

}