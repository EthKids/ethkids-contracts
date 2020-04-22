pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title EthKidsToken
 * @dev Standard ERC20, but with disabled 'transfer' function to prevent Sybil attack
 * Owner (or a 'minter') is a community contract, and it has some extra privileges,
 * like burning tokens for a given holder
 */
contract EthKidsToken is ERC20Mintable, ERC20Detailed {

    uint256 public smallestHolding = 10 ** 18;

    constructor (string memory name, string memory symbol) ERC20Detailed(name, symbol, 18) public {
    }

    /**
     * @dev Function that burns an amount of the token of a given
     * account, and DOES NOT require holder's approval
     * @param from The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function burnFrom(address from, uint256 value) public onlyMinter {
        _burn(from, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(false, 'Community tokens can be only liquidated in the bonding curve');
    }

    function _mint(address account, uint256 value) internal {
        super._mint(account, value);
        _onBalanceChange(account);
    }

    function _burn(address account, uint256 value) internal {
        super._burn(account, value);
        _onBalanceChange(account);
    }

    function _onBalanceChange(address account) internal {
        if (balanceOf(account) < smallestHolding) {
            smallestHolding = balanceOf(account);
        }
    }

}
