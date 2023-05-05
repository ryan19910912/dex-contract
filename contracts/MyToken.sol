/**
 *Submitted for verification at Etherscan.io on 2023-03-05
 */

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {

    //初始化
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
    }

    //實作 mint 鑄造
    function mint(address account, uint amount) external {
        super._mint(account, amount);
    }

    //實作 burn 燒毀
    function burn(address account, uint amount) external {
        super._burn(account, amount);
    }
}