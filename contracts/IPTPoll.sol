// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IInukaPartnerToken {
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

contract IPTPoll is Ownable {

    IInukaPartnerToken private inukaPartnerToken;

    struct PollOutcome {
        uint256 totalVotes;
        uint256 noVotes;
        uint256 yesVotes;
    }
    /** 
    /* @notice For each project it gives the timestamp for the last voting deadline regardless of 
    /* whether it is the first or second poll
    /* @dev Use this to check if token transfer is enabled. TODO: Verify that this is a safe way
    /* to disable transfer while poll is ongoing 
    */
    mapping (uint256 => uint256) latestPollDeadline;
    /**
    /* @notice Check for each project, in each phase, if poll is active based on timestamp 
    /* in the first poll
    */
    mapping (uint256 => mapping (uint256 => uint256)) private firstPollActive;
    /**
    /* @notice Tracks for each project, in each phase, the number of votes cast by each address 
    /* in the first poll
    */
    mapping (uint256 => mapping (uint256 => mapping (address => uint256))) private firstPollCast;
    /**
    /* @notice Tracks for each project, in each phase, the total number of votes cast by all addresses 
    /* and the number of no and yes votes in the first poll
    */
    mapping (uint256 => mapping (uint256 => uint256)) private secondPollActive;
    mapping (uint256 => mapping (uint256 => PollOutcome)) private firstPollResult;
    /**
    /* @notice Tracks for each project, in each phase, the number of votes cast by each address 
    /* in the second poll
    */
    mapping (uint256 => mapping (uint256 => mapping (address => uint256))) private secondPollCast;
    /**
    /* @notice If first poll does not clear, second poll can be called
    */
    mapping (uint256 => mapping (uint256 => PollOutcome)) private secondPollResult;

    address private iPTLaunchpadAddress;

    /**
    /* @notice Voting period set to 1 week
    /* @dev To consider whether to let project creators set voting period themselves
    */
    uint256 constant VOTINGPERIOD = 1000;

    function setIPTLaunchpadAddress (address _address) external onlyOwner {
        iPTLaunchpadAddress = _address;
    }

    function setInukaPartnerToken (address _inukaPartnerTokenAddress) external onlyOwner {
        inukaPartnerToken = IInukaPartnerToken(_inukaPartnerTokenAddress);
    }

    // TODO: triggers one-week voting. 50% of holders must vote, with 50% saying yes
    // TODO: Must be called by IPTLaunchpad contract
    /**
    /* @notice Called when a Project Creator requests fund release
    */
    function createFirstPoll (uint256 _projectId, uint256 _phase) external {
        require(iPTLaunchpadAddress == msg.sender, "Unauthorised");
        latestPollDeadline[_projectId] = block.timestamp + VOTINGPERIOD;
        firstPollActive[_projectId][_phase] = block.timestamp + VOTINGPERIOD;
    }

    function createSecondPoll (uint256 _projectId, uint256 _phase) external {
        require(iPTLaunchpadAddress == msg.sender, "Unauthorised");
        latestPollDeadline[_projectId] = block.timestamp + VOTINGPERIOD;
        secondPollActive[_projectId][_phase] = block.timestamp + VOTINGPERIOD;
    }

    // TODO: Set voting active to be precise --> poll #, phase #
    /**
    /* @notice One vote per token. Voter need not cast all votes at one go.
    */
    function voteFirstPoll (
        uint256 _projectId, 
        uint256 _phase, 
        uint256 _voteCount, 
        bool _voteChoice
    ) external {
        require(firstPollActive[_projectId][_phase] < block.timestamp, "Poll over");
        require(inukaPartnerToken.balanceOf(msg.sender, _projectId) >= firstPollCast[_projectId][_phase][msg.sender], "No votes left");
        firstPollCast[_projectId][_phase][msg.sender] += _voteCount;
        firstPollResult[_projectId][_phase].totalVotes += _voteCount;
        if (_voteChoice) {
            firstPollResult[_projectId][_phase].yesVotes += _voteCount;
        } else {
            firstPollResult[_projectId][_phase].noVotes += _voteCount;
        }
    }

    function voteSecondPoll (
        uint256 _projectId, 
        uint256 _phase, 
        uint256 _voteCount, 
        bool _voteChoice
    ) external {
        require(secondPollActive[_projectId][_phase] < block.timestamp, "Poll over");
        require(inukaPartnerToken.balanceOf(msg.sender, _projectId) >= secondPollCast[_projectId][_phase][msg.sender], "No votes left");
        secondPollCast[_projectId][_phase][msg.sender] += _voteCount;
        secondPollResult[_projectId][_phase].totalVotes += _voteCount;
        if (_voteChoice) {
            secondPollResult[_projectId][_phase].yesVotes += _voteCount;
        } else {
            secondPollResult[_projectId][_phase].noVotes += _voteCount;
        }
    } 

    function getFirstPollActive (uint256 _projectId, uint256 _phase) external view returns (bool pollStatus) {
        pollStatus = firstPollActive[_projectId][_phase] < block.timestamp;
    }

    function getSecondPollActive (uint256 _projectId, uint256 _phase) external view returns (bool pollStatus) {
        pollStatus = secondPollActive[_projectId][_phase] < block.timestamp;
    }

    // TODO: Remove if not used
    function setFirstPollActive (uint256 _projectId, uint256 _phase) internal {
        firstPollActive[_projectId][_phase] = block.timestamp + VOTINGPERIOD;
    }

    function getFirstPollResult (uint256 _projectId, uint256 _phase) external view returns (PollOutcome memory resultFound) {
        resultFound = firstPollResult[_projectId][_phase];
    }

    function getSecondPollResult (uint256 _projectId, uint256 _phase) external view returns (PollOutcome memory resultFound) {
        resultFound = secondPollResult[_projectId][_phase];
    }
}