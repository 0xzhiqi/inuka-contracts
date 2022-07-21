// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyUSDC is ERC20 {
    constructor() ERC20("DummyUSDC", "USDC") {
        _mint(address(this), 1e36);
    }

    /** 
    @notice Sends 50,000 Mock USDC to anyone to use in RightsToken contract
    */
    function requestTokens() public {
        _transfer(address(this), msg.sender, 50e18);
    }
}