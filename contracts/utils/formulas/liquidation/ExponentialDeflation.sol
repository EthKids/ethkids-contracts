pragma solidity ^0.5.2;

import "./FractionalExponents.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ExponentialDeflation {

    using SafeMath for uint256;
    uint32 reserveRatio = 100000;

    FractionalExponents public exponentContract;


    constructor() public {
        exponentContract = new FractionalExponents();
    }

    /**
      * @dev given a token supply, reserve balance, ratio and a deposit amount (in the reserve token),
      * calculates the return for a given conversion (in the main token)
      *
      * Formula:
      * Return = _supply * ((1 + _depositAmount / _currentHoldings) ^ (_reserveRatio / 1000000) - 1)
      *
      * @param _supply              token total supply
      * @param _currentHoldings     current personal holdings
      * @param _depositAmount       deposit amount, in reserve token
      *
      * @return purchase return amount
    */
    function calculatePurchaseReturn(uint256 _supply, uint256 _currentHoldings, uint256 _depositAmount) public view returns (uint256) {
        // validate input
        require(_supply > 0 && _currentHoldings > 0);

        // special case for 0 deposit amount
        if (_depositAmount == 0)
            return 0;

        uint256 result;
        uint8 precision;
        uint256 baseN = _depositAmount.add(_currentHoldings);
        (result, precision) = exponentContract.power(baseN, _currentHoldings, reserveRatio, 1000000);
        uint256 temp = _supply.mul(result) >> precision;
        return temp - _supply;
    }

    /**
      * @dev given a token supply, reserve balance, ratio and a sell amount (in the main token),
      * calculates the return for a given conversion (in the reserve token)
      *
      * Formula:
      * Return = _currentHoldings * (1 - (1 - _sellAmount / _supply) ^ (1000000 / _reserveRatio))
      *
      * @param _supply              token total supply
      * @param _currentHoldings     current personal holdings
      * @param _sellAmount          sell amount, in the token itself
      *
      * @return sale return amount
    */
    function calculateSaleReturn(uint256 _supply, uint256 _currentHoldings, uint256 _sellAmount) public view returns (uint256) {
        // validate input
        require(_supply > 0 && _currentHoldings > 0 && _sellAmount <= _supply);

        // special case for 0 sell amount
        if (_sellAmount == 0)
            return 0;

        // special case for selling the entire supply
        if (_sellAmount == _supply)
            return _currentHoldings;

        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _sellAmount;
        (result, precision) = exponentContract.power(_supply, baseD, 1000000, reserveRatio);
        uint256 temp1 = _currentHoldings.mul(result);
        uint256 temp2 = _currentHoldings << precision;
        return (temp1 - temp2) / result;
    }

}