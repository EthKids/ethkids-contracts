pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title GrowingInflationV1 formula
 * @dev Contract used to calculate the reward in tokens for a donation
 * The price is calculated based on the personal donator's current holding,
 * with the use of 'default' value for an initial donation.
 * The idea is to allow fast growing at start
 */
contract GrowingInflationV1 {
    using SafeMath for uint256;

    function applyFormula(uint256 _ethAmount, uint256 _tokenBalance, uint256 _tokenSupply, uint256 _ethInVault)
    public pure returns (uint256 finalPrice, uint256 tokenAmount) {
        // For EVM accuracy
        uint256 _multiplier = 10 ** 18;
        if (_tokenBalance == 0) {
            //new donator, offer the starting price
            _tokenBalance = 100 finney;
        }
        // price depends on the personal portion, i.e. 10% portion will be (0.1 * _multiplier)
        finalPrice = _tokenBalance.mul(_multiplier).div(_tokenSupply);

        //to get some readable token amount at the beginning
        uint256 amplifier = 100;
        tokenAmount = _ethAmount.mul(finalPrice).div(_multiplier).mul(amplifier);

        return (finalPrice, tokenAmount);
    }
}