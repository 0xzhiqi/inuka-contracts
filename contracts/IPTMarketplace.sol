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

contract IPTMarketplace is Ownable {
    IMockUsdc public mockUsdc;
    IInukaPlasticCredit private inukaPlasticCredit;

    struct ListingDetail {
        address lister;
        uint256 price;
        uint256 amount;
        bool active;
    }

    mapping (uint256 => bool) pollActive;
    /**
    /* @notice Shows for each token the primary listing details
    */
    mapping (uint256 => ListingDetail) private primaryListingFeed;
    /**
    /* @notice Tracks for each tokenId the number of tokens sold in primary sale
    */
    mapping (uint256 => uint256) private primarySaleToken;
    /**
    /* @notice Tracks for each tokenId the number of tokens sold in primary sale
    */
    mapping (uint256 => uint256) private primarySaleRevenue;
    /**
    /* @notice Tracks for each tokenId a strictly increasing index on total number of listings,
    /* both active and inactive
    */
    mapping(uint256 => uint256) private secondarylistingIndexTracker;
    /**
    /* @notice For each tokenId maps the index from secondarylistingIndexTracker to ListingDetail
    */
    mapping (uint256 => mapping (uint256 => ListingDetail)) private secondaryListingFeed;
    /**
    /* @notice Tracks for each projectId how much each wallet has funded it
    /* @dev To reconsider if this is necessary, or we can derive this value directly from wallet balance and price
    */
    mapping (uint256 => mapping(address => uint256)) private funderTracker;

    // TODO: Add events here

    // TODO: Add modifiers here

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

    /**
    /* @notice All tokens minted have to be listed
    /* @dev To add option for bonding curve next to test if it incentivises early purchase
    */
    // TODO: Add check to verify that wallet balance is the same as total minted
    // TODO: Include number of phases and funds needed for each phase
    // TODO: Verfiy that above adds up to total amount to raise
    function listPrimaryToken (
        uint256 _tokenId, 
        uint256 _amount, 
        uint256 _price
        ) external 
        onlyProjectCreator(_tokenId) 
    {
        require(inukaPlasticCredit.balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance");
        require(_price > 0, "No price");
        inukaPlasticCredit.setApprovalForAll(address(this), true);
        _setPrimaryListingDetail(_tokenId, msg.sender, _price, _amount);
    }

    // Need to delist all
    // USDC paid by buyers can now be redeemed
    // TODO: Consider whether to remove approval
    function delistPrimaryToken () external {
        
    }

    function buyPrimaryToken (uint256 _tokenId, uint256 _amount) external {
        uint256 totalPrice = primaryListingFeed[_tokenId].price * _amount;
        if (mockUsdc.balanceOf(msg.sender) <= totalPrice) {
            revert IPTMarketplace__InsufficientBalance({
                balance: mockUsdc.balanceOf(msg.sender),
                required: totalPrice
            });
        }
        primarySaleToken[_tokenId] += _amount;
        primarySaleRevenue[_tokenId] += totalPrice;
        mockUsdc.transferFrom(msg.sender, address(this), totalPrice);
    }

    function listSecondaryToken (
        uint256 _tokenId, 
        uint256 _amount, 
        uint256 _price
        ) external 
        onlyProjectCreator(_tokenId) 
    {
        require(inukaPlasticCredit.balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance");
        require(_price > 0, "No price");
        inukaPlasticCredit.setApprovalForAll(address(this), true);
        secondarylistingIndexTracker[_tokenId]++;
        _setSecondaryListingDetail(_tokenId, secondarylistingIndexTracker[_tokenId], msg.sender, _price, _amount);
    }

    function delistSecondaryToken () external {}

    /**
    /* @dev From the frontend, for 2 listings with the same price, the listing that was put up first 
    /* will be sold first i.e. FIFO
    */
    function buySecondaryToken (
        uint256[] calldata _tokenId, 
        uint256[] calldata _index, 
        uint256[] calldata _price, 
        uint256[] calldata _amount,
        uint256 _arrayLength
        ) external {
            // TODO: Check if gas can be optimised with separate error statements
            if (
                _tokenId.length != _arrayLength || 
                _index.length != _arrayLength || 
                _price.length != _arrayLength || 
                _amount.length != _arrayLength 
            ) {
                revert IPTMarketplace__BuyTokenArrayLengthMismatch({
                    tokenId: _tokenId.length,  
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

    // triggers one-week voting. 50% of holders must vote, with 50% saying yes
    // only project creator can request fund release
    function requestFundRelease (uint256 _projectId) external onlyProjectCreator( _projectId) {}

    // poll created within requestFundRelease
    // disables token transfer
    function createPoll () internal {}

    // only project creator can release fund 
    function releaseFund () external {} 

    function getPollActive (uint256 _projectId) external view returns (bool pollStatus) {
        pollStatus = pollActive[_projectId];
    }

    // Can only be set through function controlled only by project creator
    function setPollActive (uint256 _projectId, bool _status) internal {
        pollActive[_projectId] = _status;
    }

    // TODO: Test that it updates if there is a new primary listing for the same tokenId
    function _setPrimaryListingDetail (
        uint256 _tokenId, 
        address _lister,
        uint256 _price,
        uint256 _amount
        ) private {
        primaryListingFeed[_tokenId].lister = _lister;
        primaryListingFeed[_tokenId].price = _price;
        primaryListingFeed[_tokenId].amount = _amount;
        primaryListingFeed[_tokenId].active = true;
    }

    
    function getSecondaryPrice (uint256 _tokenId, uint256 _index) public view returns (uint256 priceFound){
        priceFound = secondaryListingFeed[_tokenId][_index].price;
    }

    // to add complementary functions - track address of listers
    /**
    /* Used in listToken function
    */
    function _setSecondaryListingDetail (
        uint256 _tokenId, 
        uint256 _index,
        address _lister,
        uint256 _price,
        uint256 _amount
        ) private {
        secondaryListingFeed[_tokenId][_index].lister = _lister;
        secondaryListingFeed[_tokenId][_index].price = _price;
        secondaryListingFeed[_tokenId][_index].amount = _amount;
        secondaryListingFeed[_tokenId][_index].active = true;
    }

}