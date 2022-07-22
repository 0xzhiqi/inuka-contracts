// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

contract IPTPoll {

    mapping (uint256 => bool) pollActive;
    
    // poll created within requestFundRelease
    // disables token transfer
    function createPoll () external {}

    function getPollActive (uint256 _projectId) external view returns (bool pollStatus) {
        pollStatus = pollActive[_projectId];
    }

    // Can only be set through function controlled only by project creator
    function setPollActive (uint256 _projectId, bool _status) internal {
        pollActive[_projectId] = _status;
    }
}