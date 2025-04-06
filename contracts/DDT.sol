//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DDTOken is ERC20 {
    address public _owner;
    
    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    // TODO: replace 0000 with your last 4 digits of student ID
    constructor(uint256 initialSupply) ERC20("DDT4024", "DDT")
    {
        _owner = msg.sender;
        _mint(msg.sender, initialSupply);

    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}