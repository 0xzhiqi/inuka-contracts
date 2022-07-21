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

contract InukaPartnerTokenMarketplace is Ownable {
    IMockUsdc public mockUsdc;

    function setMockUsdc (address _mockUsdcAddress) external onlyOwner {
        mockUsdc = IMockUsdc(_mockUsdcAddress);
    }

    // Include number of phases and funds needed for each phase
    // number of
    /**
    @dev To add option for bonding curve next to test if it incentivises early purchase
    */
    function listToken () external {}

    // Need to delist all
    // USDC paid by buyers can now be redeemed
    function delistToken () external {}

    function buyToken () external {}

    // triggers one-week voting. 50% of holders must vote, with 50% saying yes
    // only project creator can request fund release
    function requestFundRelease () external {}

    // poll created within requestFundRelease
    // disables token transfer
    function createPoll () internal {}

    // only project creator can release fund 
    function releaseFund () external {} 
    


}