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
    function getProject(uint256 _projectId) external view returns (Project memory _project);
}

interface IInukaPartnerToken {
    function getMintedAmount (uint256 _projectId) external view returns (uint256 mintedAmountFound);
    function deactivateMint (uint256 _projectId) external;
    function undoDeactivateMint (uint256 _projectId) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function setApprovalForAll(address operator, bool approved) external;
}

interface IIPTPoll {
    struct PollOutcome {
        uint256 totalVotes;
        uint256 noVotes;
        uint256 yesVotes;
    }
    function createFirstPoll (uint256 _projectId, uint256 _phase) external;
    function getFirstPollResult (uint256 _projectId, uint256 _phase) external view returns (PollOutcome memory resultFound);
    function getFirstPollActive (uint256 _projectId, uint256 _phase) external view returns (bool pollStatus);
    function createSecondPoll (uint256 _projectId, uint256 _phase) external;
    function getSecondPollResult (uint256 _projectId, uint256 _phase) external view returns (PollOutcome memory resultFound);
    function getSecondPollActive (uint256 _projectId, uint256 _phase) external view returns (bool pollStatus);
}

error IPTLaunchpad__InsufficientBalance(
    uint256 balance,
    uint256 required
);

contract IPTLaunchpad is Ownable {
    IMockUsdc public mockUsdc;
    IInukaPlasticCredit private inukaPlasticCredit;
    IInukaPartnerToken private inukaPartnerToken;
    IIPTPoll private iPTPoll;

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

    /**
    /* @notice Shows for each token the primary listing details
    */
    mapping (uint256 => PrimaryListingDetail) private primaryListingFeed;
    /**
    /* @notice Tracks for each tokenId the number of tokens sold in primary sale
    */
    mapping (uint256 => uint256) private primarySaleToken;
    // TODO: Consider removing primarySaleRevenue since it can be derived from primarySaleToken
    /**
    /* @notice Tracks for each tokenId the number of tokens sold in primary sale
    */
    mapping (uint256 => uint256) private primarySaleRevenue;
    /**
    /* @notice Show where for a tokenId refunding is ongoing
    */
    mapping (uint256 => bool) private refundActive;

    mapping (uint256 => mapping (address => bool)) private refunded;

    mapping (uint256 => bool) private fundingComplete;

    mapping (uint256 => uint256) private currentPhase;

    /**
    /* @notice Tracks for each projectId at each phase if the fund has been released to project creator
    */
    mapping (uint256 => mapping(uint256 => bool)) fundReleased;

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

    function setIPTPoll (address _iPTPollAddress) external onlyOwner {
        iPTPoll = IIPTPoll(_iPTPollAddress);
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
        require(inukaPartnerToken.balanceOf(msg.sender, _projectId) >= _amount, "Insufficient balance");
        // Ensure all minted tokens are listed
        require(inukaPartnerToken.getMintedAmount(_projectId) == _amount, "Not all tokens listed");
        require(!refundActive[_projectId], "Refunding");
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
        inukaPartnerToken.setApprovalForAll(address(this), true);
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

    /**
    /* @notice To let holders get back usdc paid when a project is delisted. Holders get to keep the tokens
    /* even after redeeming
    */
    function getRefund (uint256 _projectId) external {
        require(refundActive[_projectId], "Refund Inactive");
        require(inukaPartnerToken.balanceOf(msg.sender, _projectId) > 0, "Not holder");
        require(!refunded[_projectId][msg.sender], "Refunded");
        refunded[_projectId][msg.sender] = true;
        mockUsdc.transferFrom(
            address(this), 
            msg.sender, 
            primaryListingFeed[_projectId].price * inukaPartnerToken.balanceOf(msg.sender, _projectId)
        );
    }

    // TODO: Check if precision of Usdc raised could be an issue: 99.999% vs 100% 
    /**
    /* @notice For anyone to call to enable refund if fundraising target not hit by deadline
    */
    function requestRefund (uint256 _projectId) external {
        require(block.timestamp > primaryListingFeed[_projectId].fundraiseEnds, "Fundraise ongoing");
        require(primaryListingFeed[_projectId].amount - primarySaleToken[_projectId] > 1e4, "Funding Complete" );
        refundActive[_projectId] = true;
    }

    // TODO
    // Withdraws phase 1 funds
    // Change mapping fundingComplete = true
    function startProject (uint256 _projectId) external onlyProjectCreator ( _projectId) {
        require(primaryListingFeed[_projectId].amount - primarySaleToken[_projectId] < 1e4, "Funding Incomplete" );
        require(!fundReleased[_projectId][currentPhase[_projectId]], "Fund released"); //TODO Verify that this works without initial update
        fundingComplete[_projectId] = true;
        fundReleased[_projectId][currentPhase[_projectId]] = true;
        mockUsdc.transferFrom(
            address(this), 
            msg.sender, 
            primaryListingFeed[_projectId].phasesFund[currentPhase[_projectId]]
        );
        currentPhase[_projectId]++;
    }

    // TODO: Check that there is still a phase with unreleased funds
    // TODO: disable token transfer by checking if block.timestamp > latestPollDeadline
    /**
    /* @notice For project creator to request funds for next phase to be released
    */
    function fundReleaseFirstRequest (uint256 _projectId) external onlyProjectCreator ( _projectId) {
        require(fundingComplete[_projectId], "Funding Incomplete");
        iPTPoll.createFirstPoll(_projectId, currentPhase[_projectId]);
    }

    // TODO: Add check that first request is over and failed
    function fundReleaseSecondRequest (uint256 _projectId) external onlyProjectCreator ( _projectId) {
        require(fundingComplete[_projectId], "Funding Incomplete");
        require(!iPTPoll.getFirstPollActive(_projectId, currentPhase[_projectId]), "First poll active");
        require(
            primarySaleToken[_projectId] - iPTPoll.getFirstPollResult(_projectId, currentPhase[_projectId]).totalVotes * 2 >= 0 ||
            iPTPoll.getFirstPollResult(_projectId, currentPhase[_projectId]).noVotes - iPTPoll.getFirstPollResult(_projectId, currentPhase[_projectId]).yesVotes >= 0, 
            "First vote passed"
        );
        iPTPoll.createSecondPoll(_projectId, currentPhase[_projectId]);
    }

    // TODO: Use if else statements? One for first poll and other for second poll
    // TODO: First check if first poll is past deadline and votes pass
    // TODO: Else check first poll is past deadline and votes pass
    /**
    /* @notice For Project Creator to request release of next phase's funds after polling clears
    */
    function releaseFundFirstPoll (uint256 _projectId, uint256 _phase) public onlyProjectCreator ( _projectId) {
        require(fundingComplete[_projectId], "Funding Incomplete");
        require(!iPTPoll.getFirstPollActive(_projectId, _phase), "First poll active");
        require(!fundReleased[_projectId][currentPhase[_projectId]], "Fund released");
        require(
            primarySaleToken[_projectId] - iPTPoll.getFirstPollResult(_projectId, _phase).totalVotes * 2 < 0, 
            "Insufficient votes"
        );
        require(
            iPTPoll.getFirstPollResult(_projectId, _phase).noVotes - iPTPoll.getFirstPollResult(_projectId, _phase).yesVotes < 0,
            "Voted No"
        );
        fundReleased[_projectId][currentPhase[_projectId]] = true;
        mockUsdc.transferFrom(
            address(this), 
            msg.sender, 
            primaryListingFeed[_projectId].phasesFund[currentPhase[_projectId]]
        );
        currentPhase[_projectId]++;
    } 

    function releaseFundSecondPoll (uint256 _projectId, uint256 _phase) public onlyProjectCreator ( _projectId) {
        require(fundingComplete[_projectId], "Funding Incomplete");
        require(!iPTPoll.getSecondPollActive(_projectId, _phase), "Second poll active");
        require(!fundReleased[_projectId][currentPhase[_projectId]], "Fund released");
        require(
            primarySaleToken[_projectId] - iPTPoll.getSecondPollResult(_projectId, _phase).totalVotes * 2 < 0, 
            "Insufficient votes"
        );
        require(
            iPTPoll.getSecondPollResult(_projectId, _phase).noVotes - iPTPoll.getSecondPollResult(_projectId, _phase).yesVotes < 0,
            "Voted No"
        );
        fundReleased[_projectId][currentPhase[_projectId]] = true;
        mockUsdc.transferFrom(
            address(this), 
            msg.sender, 
            primaryListingFeed[_projectId].phasesFund[currentPhase[_projectId]]
        );
        currentPhase[_projectId]++;
    } 

    // TODO: Test that it updates i.e. overwrites mapping if there is a new primary listing for the same tokenId
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