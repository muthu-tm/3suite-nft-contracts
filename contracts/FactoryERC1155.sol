// contracts/FactoryERC1155.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./ERC1155Token.sol";

contract FactoryERC1155 is Ownable {

    ERC1155Token[] public tokens; //an array that contains different ERC1155 tokens deployed

    event ERC1155Created(address owner, address tokenContract); //emitted when ERC1155 token is deployed
    event ERC1155Minted(address owner, address tokenContract, uint amount); //emmited when ERC1155 token is minted

    /*
    deployERC1155 - deploys a ERC1155 token with given parameters - returns deployed address

    _contractName - name of our ERC1155 token
    _uri - URI resolving to our hosted metadata
    _ids - IDs the ERC1155 token should contain
    _name - Names each ID should map to. Case-sensitive.
    */
    function deployERC1155(string memory _contractName, string memory _uri, uint[] memory _ids, string[] memory _names) public returns (address) {
        ERC1155Token t = new ERC1155Token(_contractName, _uri, _names, _ids);
        tokens.push(t);
        emit ERC1155Created(msg.sender,address(t));
        return address(t);
    }

    /*
    mintERC1155 - mints a ERC1155 token with given parameters

    _index - index position in our tokens array - represents which ERC1155 you want to interact with
    _name - Case-sensitive. Name of the token (this maps to the ID you created when deploying the token)
    _amount - amount of tokens you wish to mint
    */
    function mintERC1155(uint _index, uint id, uint256 amount) public {
        ERC1155Token token = tokens[_index];
        token.mint(token.owner(), id, amount);
        emit ERC1155Minted(token.owner(), address(token), amount);
    }

    /*
    Helper functions below retrieve contract data given an ID or name and index in the tokens array.
    */
    function getCountERC1155byIndex(uint256 _index, uint256 _id) public view returns (uint amount) {
        ERC1155Token token = tokens[_index];
        return token.balanceOf(token.owner(), _id);
    }

    function getERC1155byIndexAndId(uint _index, uint _id)
        public
        view
        returns (
            address _contract,
            address _owner,
            string memory _uri,
            uint supply
        )
    {
        ERC1155Token token = tokens[_index];
        return (address(token), token.owner(), token.uri(_id), token.balanceOf(token.owner(), _id));
    }
}