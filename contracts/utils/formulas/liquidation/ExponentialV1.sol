pragma solidity ^0.5.2;

import ".././FractionalExponents.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title ExponentialV1 formula
 * @dev Contract used to calculate the return in case of token's liquidation
 * Mostly taken from https://github.com/khana-io/BondedDonations
 */
contract ExponentialV1 {
    using SafeMath for uint256;

    FractionalExponents public exponentContract;

    constructor() public {
        exponentContract = new FractionalExponents();
    }

    function applyFormula(uint256 _tokenAmount, uint256 _tokenBalance, uint256 _tokenSupply, uint256 _ethInVault)
    public view returns (uint256 _finalPrice, uint256 _redeemableEth) {
        // For EVM accuracy
        uint256 _multiplier = 10 ** 18;

        // a = (Sp.10^8)
        uint256 _portionE8 = (_tokenBalance.mul(10 ** 8).div(_tokenSupply));

        // b = a^1/10
        (uint256 _exponentResult, uint8 _precision) = exponentContract.power(_portionE8, 1, 1, 10);

        // b/8 * (funds backing curve / token supply)
        uint256 _interimPrice = (_exponentResult.div(8)).mul(_ethInVault.mul(_multiplier).div(_tokenSupply)).div(_multiplier);

        // get final price (with multiplier)
        _finalPrice = (_interimPrice.mul(_multiplier)).div(2 ** uint256(_precision));

        // redeemable ETH (without multiplier)
        _redeemableEth = _finalPrice.mul(_tokenAmount).div(_multiplier);
        return (_finalPrice, _redeemableEth);
    }


}