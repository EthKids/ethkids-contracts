pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./token/EthKidsToken.sol";
import "./RegistryInterface.sol";
import "./RegistryAware.sol";

/**
 * @title BondingVault
 * @dev The vault which holds the donor's community funds and mints the token as a reward.
 * The community members are free to liquidate their token at any moment for a personal ETH price
 * The 'admin' is the EthKidsRegistry creator
 * The 'whitelisted' are the registered communities. The 'reward' minting happens only via donation to any of a community
 * The vault can be 'charged' with ETH by anyone but no reward will be minted in return
 */
contract BondingVault is BondingVaultInterface, RegistryAware, WhitelistedRole {
    using SafeMath for uint256;

    RegistryInterface public registry;
    EthKidsToken public token;

    BondingCurveFormula public bondingCurveFormula;

    event LogEthReceived(
        uint256 amount,
        address indexed account
    );
    event LogEthSent(
        uint256 amount,
        address indexed account
    );
    event LogTokensSold(address from, uint256 amount);
    event LogTokensMinted(address to, uint256 amount);


    /**
    * @dev funding bondingVault and not receiving tokens back is allowed
    **/
    function() external payable {
        emit LogEthReceived(msg.value, msg.sender);
    }

    constructor(string memory _tokenName, string memory _tokenSymbol, address _formulaAddress, uint256 _initialMint)
    public payable{
        token = new EthKidsToken(_tokenName, _tokenSymbol);
        token.mint(msg.sender, _initialMint);
        bondingCurveFormula = BondingCurveFormula(_formulaAddress);
        emit LogEthReceived(msg.value, msg.sender);
    }

    function setRegistry(address _registry) public onlyWhitelistAdmin {
        registry = (RegistryInterface)(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

    /**
    * @dev Receives ETH and mints the rewarding token in return
    * Can be called by a community only (i.e. via a 'donation' action)
    */
    function fundWithReward(address payable _donor) public payable onlyWhitelisted {
        uint256 _tokenAmount = calculateReward(msg.value, _donor);

        token.mint(_donor, _tokenAmount);
        emit LogEthReceived(msg.value, _donor);
        emit LogTokensMinted(msg.sender, _tokenAmount);
    }

    /**
    * @dev Burn token and receive ETH back
    */
    function sell(uint256 _amount) public {
        uint256 amountOfEth = calculateReturn(_amount, msg.sender);
        require(address(this).balance > amountOfEth, 'Insufficient funds in the vault');
        token.burnFrom(msg.sender, _amount);

        msg.sender.transfer(amountOfEth);
        emit LogEthSent(amountOfEth, msg.sender);
        emit LogTokensSold(msg.sender, amountOfEth);
    }

    /**
    * @dev Recovery in case of emergency
    *
    */
    function sweepVault(address payable _operator) public onlyWhitelistAdmin {
        require(address(this).balance > 0, 'Vault is empty');
        _operator.transfer(address(this).balance);
        emit LogEthSent(address(this).balance, _operator);
    }

    function calculateReward(uint256 _ethAmount, address payable _donor) public
    view returns (uint256 tokenAmount) {
        uint256 _tokenSupply = token.totalSupply();
        uint256 _tokenBalance = token.balanceOf(_donor);
        if (_tokenBalance == 0) {
            //first donation, offer best market price
            _tokenBalance = token.smallestHolding();
        }
        return bondingCurveFormula.calculatePurchaseReturn(_tokenSupply, _tokenBalance, address(this).balance.sub(_ethAmount), _ethAmount);
    }

    function calculateReturn(uint256 _tokenAmount, address payable _donor) public
    view returns (uint256 returnEth) {
        uint256 _tokenBalance = token.balanceOf(_donor);
        require(_tokenAmount > 0 && _tokenBalance >= _tokenAmount, "Amount needs to be > 0 and tokenBalance >= amount to sell");

        uint256 _tokenSupply = token.totalSupply();
        return bondingCurveFormula.calculateSaleReturn(_tokenSupply, _tokenBalance, address(this).balance, _tokenAmount);
    }

    function getEthKidsToken() public view returns (address) {
        return address(token);
    }

}

interface BondingCurveFormula {

    function calculatePurchaseReturn(uint256 _supply, uint256 _currentHoldings, uint256 _reserveBalance, uint256 _depositAmount) external view returns (uint256);

    function calculateSaleReturn(uint256 _supply, uint256 _currentHoldings, uint256 _reserveBalance, uint256 _sellAmount) external view returns (uint256);

}
