// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable{
    
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable(){}

    function mintNew(address _to, uint _id) external onlyOwner{
        _safeMint(_to, _id);
    }
}