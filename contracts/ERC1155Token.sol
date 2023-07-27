// contracts/ERC1155Token.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ERC1155Token is ERC1155, Ownable {
    string[] public names; //string array of names
    uint[] public ids; //uint array of ids
    string public baseMetadataURI; //the token metadata URI
    string public name; //the token name
    uint public mintFee = 0 wei; //mintfee, 0 by default. only used in mint function, not batch.

    constructor(
        string memory _contractName,
        string memory _uri,
        string[] memory _names,
        uint[] memory _ids
    ) ERC1155(_uri) {
        names = _names;
        ids = _ids;
        setURI(_uri);
        baseMetadataURI = _uri;
        name = _contractName;
        transferOwnership(tx.origin);
    }

    /*
    * sets our URI and makes the ERC1155 OpenSea compatible
    */
    function uri(
        uint256 _tokenid
    ) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    baseMetadataURI,
                    Strings.toString(_tokenid),
                    ".json"
                )
            );
    }

    function getNames() public view returns (string[] memory) {
        return names;
    }

    /*
    * used to change metadata, only owner access
    */
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /*
    * set a mint fee. only used for mint, not batch.
    */
    function setFee(uint _fee) public onlyOwner {
        mintFee = _fee;
    }

    function mint(
        address account,
        uint _id,
        uint256 amount
    ) public payable onlyOwner returns (uint) {
        require(msg.value == mintFee);
        _mint(account, _id, amount, "");
        return _id;
    }

    function mintBatch(
        address to,
        uint256[] memory _ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, _ids, amounts, data);
    }
}
