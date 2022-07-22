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

error IPTLaunchpad__InsufficientBalance(
    uint256 balance,
    uint256 required
);

error IPTLaunchpad__ (

);

contract IPTLaunchpad is Ownable {
    IMockUsdc public mockUsdc;
    IInukaPlasticCredit private inukaPlasticCredit;
    IInukaPartnerToken private inukaPartnerToken;

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

    mapping (uint256 => bool) pollActive;
    /**
    /* @notice Shows for each token the primary listing details
    */
    mapping (uint256 => PrimaryListingDetail) private primaryListingFeed;
    /**
    /* @notice Tracks for each tokenId the number of tokens sold in primary sale
    */
    mapping (uint256 => uint256) private primarySaleToken;
    /**
    /* @notice Tracks for each tokenId the number of tokens sold in primary sale
    */
    mapping (uint256 => uint256) private primarySaleRevenue;
    /**
    /* @notice Show where for a tokenId refunding is ongoing
    */
    mapping (uint256 => bool) private refundActive;

    /**
    /* @notice Tracks for each projectId how much each wallet has funded it
    /* @dev To reconsider if this is necessary, or we can derive this value directly from wallet balance and price
    */
    mapping (uint256 => mapping(address => uint256)) private funderTracker;

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

    /**
    /* @notice All tokens minted have to be listed. Total funds across the phases have to equal the total
    /* by multiplying listing price with amount of tokens to sell
    /* @dev To add option for bonding curve next to test if it incentivises early purchase.
    /* To consider allowing more than 5 phases
    */
    function listPrimaryToken (
        uint256 _projectId, 
        uint256 _price, 
        uint256 _amount,
        uint256 _fundraiseEnds,
        uint256 _projectStarts,
        uint256 _phasesNumber,
        uint256[] calldata _phasesDate,
        uint256[] calldata _phasesFund
        ) external 
        onlyProjectCreator(_projectId) 
    {
        require(inukaPlasticCredit.balanceOf(msg.sender, _projectId) >= _amount, "Insufficient balance");
        // Ensure all minted tokens are listed
        require(inukaPartnerToken.getMintedAmount(_projectId) == _amount, "Not all tokens listed");
        require(_price > 0, "No price");
        require(_phasesNumber < 6, "More than 5 phases");
        uint256 phasesFundTotal;
        uint256 phaseCount; 
        while (phaseCount < _phasesNumber){
            phasesFundTotal += _phasesFund[phaseCount];
            phaseCount++;
        }
        require(phasesFundTotal == _price * _amount, "Funds not matched");
        require(_fundraiseEnds > block.timestamp, "Invalid date");
        require(_projectStarts > _fundraiseEnds, "Invalid date");
        phaseCount = 1;
        while (phaseCount < _phasesNumber) {
            // Check the dates are valid i.e. one after another
            // TODO: Switch to custom error
            require(_phasesDate[phaseCount - 1] < _phasesDate[phaseCount], "Invalid date");
            phaseCount++;
        }
        inukaPartnerToken.deactivateMint(_projectId);
        inukaPlasticCredit.setApprovalForAll(address(this), true);
        _setPrimaryListingDetail(
            _projectId, 
            msg.sender, 
            _price, 
            _amount, 
            _fundraiseEnds,
            _projectStarts,
            _phasesNumber,
            _phasesDate,
            _phasesFund
        );
        // TODO: Add back refundActive
        // refundActive[_projectId] = false;
    }

    // TODO: Consider whether to remove approval
    /**
    /* @notice Sale of all tokens for the tokenId stops. Token holder can claim refund
    /* @dev To consider whether to burn delisted tokens
    */
    function delistPrimaryToken (uint256 _projectId) external onlyProjectCreator(_projectId)  {
        primaryListingFeed[_projectId].active = false;
        refundActive[_projectId] = true;
        inukaPartnerToken.undoDeactivateMint(_projectId);
    }

    // TODO: Check if changing require statement to custom error saves gas
    function buyPrimaryToken (uint256 _projectId, uint256 _amount) external {
        require (primaryListingFeed[_projectId].active, "Sale Inactive");
        uint256 totalPrice = primaryListingFeed[_projectId].price * _amount;
        if (mockUsdc.balanceOf(msg.sender) <= totalPrice) {
            revert IPTLaunchpad__InsufficientBalance({
                balance: mockUsdc.balanceOf(msg.sender),
                required: totalPrice
            });
        }
        primarySaleToken[_projectId] += _amount;
        primarySaleRevenue[_projectId] += totalPrice;
        mockUsdc.transferFrom(msg.sender, address(this), totalPrice);
    }

    function refund () external {}

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
        uint256 _projectId, 
        address _lister,
        uint256 _price,
        uint256 _amount,
        uint256 _fundraiseEnds,
        uint256 _projectStarts,
        uint256 _phasesNumber,
        uint256[] calldata _phasesDate,
        uint256[] calldata _phasesFund
        ) private {
        primaryListingFeed[_projectId].lister = _lister;
        primaryListingFeed[_projectId].price = _price;
        primaryListingFeed[_projectId].amount = _amount;
        primaryListingFeed[_projectId].fundraiseEnds = _fundraiseEnds;
        primaryListingFeed[_projectId].projectStarts = _projectStarts;
        primaryListingFeed[_projectId].phasesCount = _phasesNumber;
        primaryListingFeed[_projectId].phasesDate = _phasesDate;
        primaryListingFeed[_projectId].phasesFund = _phasesFund;
        primaryListingFeed[_projectId].active = false;
    }

    function startPrimarySale (uint256 _projectId) external onlyProjectCreator( _projectId) {
        primaryListingFeed[_projectId].active = true;
    }

}