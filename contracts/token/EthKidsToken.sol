pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title EthKidsToken
 * @dev ERC20
 * Owner (or a 'minter') is a bonding vault contract, and it can burn the token upon sale
 * like burning tokens for a given holder
 */
contract EthKidsToken is ERC20Mintable, ERC20Detailed {

    constructor (string memory name, string memory symbol) ERC20Detailed(name, symbol, 18) public {
    }

    /**
     * @dev Function that burns an amount of the token of a given
     * account, and DOES NOT require holder's approval
     * @param from The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function burnFrom(address from, uint256 value) public onlyMinter {
        super._burn(from, value);
    }

}
