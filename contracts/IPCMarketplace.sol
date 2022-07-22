// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IInukaPlasticCredit {
    // Add approve and transfer functions
}

contract IPCMarketplace is Ownable {

    /**
    /* Once started, user cannot transfer/sell tokens
    */
    mapping (address => uint256) private percentRedeemed;

    function listPlasticCredit () external {}

    // Need not delist all
    // 
    function delistPlasticCredit () external {}

    // Cannot transfer after purchase
    // Only projectCreator can transfer plastic credit
    /**
    /* @dev Funds from Inuka plastic credit purchase goes into contract but can only be redeemed by 
    /* Inuka token holders with corresponding projectId
    */
    function buyPlasticCredit () external {}

    /**
    /* @notice Once a partner redeems, transfer of Inuka Partner token is not possible.
    /* This avoids confustion for potential buyers thinking they have bought tokens
    /* with cashflow when they in fact the revenue accrued to it has already been redeemed
    /* @dev Token stays with user forever after redemption, becoming "soul-bound". Proves
    /* user was a fundraising campaign supporter 
    */
    function redeemRevenue () external {}

    function getPercentRedeemed (address _holder) external view returns (uint256 percentRedeemedFound) {
        percentRedeemedFound = percentRedeemed[_holder];
    }

    // Test that only holder / Inuka Plastic Credit Marketplace can do this
    function setPercentRedeemed (address _holder, uint256 _percent) private {
        percentRedeemed[_holder] += _percent;
    }
}