pragma solidity ^0.5.2;

import "./FractionalExponents.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * ExponentialDeflation.sol
 * Copied and modified from:
 *  https://github.com/bancorprotocol/contracts/blob/master/solidity/contracts/converter/BancorFormula.sol
 */
contract ExponentialDeflation {

    using SafeMath for uint256;
    uint32 reserveRatio = 100000;

    FractionalExponents public exponentContract;


    constructor() public {
        exponentContract = new FractionalExponents();
    }

    /**
      * @dev given a token supply, owned tokens, reserve balance and a deposit amount (in the reserve ETH),
      * calculates the return for a given conversion (in the main token)
      *
      * Formula:
      * Return = _supply * ((1 + _depositAmount / (_reserveBalance * OWNED_PORTION)) ^ (reserveRatio / 1000000) - 1)
      *
      * @param _supply              token total supply
      * @param _currentHoldings     current personal token holdings
      * @param _reserveBalance      total ETH reserve balance
      * @param _depositAmount       deposit amount, in ETH
      *
      * @return purchase return amount
    */
    function calculatePurchaseReturn(uint256 _supply, uint256 _currentHoldings, uint256 _reserveBalance, uint256 _depositAmount) public view returns (uint256) {
        // validate input
        require(_supply > 0 && _currentHoldings > 0 && _reserveBalance > 0);

        // special case for 0 deposit amount
        if (_depositAmount == 0)
            return 0;

        uint256 personalPortion = _currentHoldings.mul(10 ** 4).div(_supply);
        // % owned, with multiplier
        _reserveBalance = _reserveBalance.mul(personalPortion).div(10 ** 4);
        // equally decrease total 'reserve'

        uint256 result;
        uint8 precision;

        uint256 baseN = _depositAmount.add(_reserveBalance);
        (result, precision) = exponentContract.power(baseN, _reserveBalance, reserveRatio, 1000000);
        uint256 temp = _supply.mul(result) >> precision;
        return temp - _supply;
    }

    /**
      * @dev given a token supply, owned tokens, reserve balance, ratio and a sell amount (in the main token),
      * calculates the return for a given conversion (in the reserve ETH)
      *
      * Formula:
      * Return = (_reserveBalance * OWNED_PORTION) * (1 - (1 - _sellAmount / _supply) ^ (1000000 / _reserveRatio))
      *
      * @param _supply              token total supply
      * @param _currentHoldings     current personal holdings
      * @param _reserveBalance      total ETH reserve balance
      * @param _sellAmount          sell amount, in the token itself
      *
      * @return sale return amount
    */
    function calculateSaleReturn(uint256 _supply, uint256 _currentHoldings, uint256 _reserveBalance, uint256 _sellAmount) public view returns (uint256) {
        // validate input
        require(_supply > 0 && _reserveBalance > 0 && _sellAmount <= _supply);

        // special case for 0 sell amount and 0 personal holdings
        if (_sellAmount == 0 || _currentHoldings == 0)
            return 0;

        // special case for selling the entire supply
        if (_sellAmount == _supply)
            return _reserveBalance;

        uint256 personalPortion = _currentHoldings.mul(10 ** 4).div(_supply);
        // % owned, with multiplier
        _reserveBalance = _reserveBalance.mul(personalPortion).div(10 ** 4);
        // equally decrease total 'reserve'

        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _sellAmount;
        (result, precision) = exponentContract.power(_supply, baseD, 1000000, reserveRatio);
        uint256 temp1 = _reserveBalance.mul(result);
        uint256 temp2 = _reserveBalance << precision;
        return (temp1 - temp2) / result;
    }

}