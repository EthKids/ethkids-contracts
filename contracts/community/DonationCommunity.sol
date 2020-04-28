pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CharityVault.sol";
import "../RegistryInterface.sol";
import "../RegistryAware.sol";
import "./IDonationCommunity.sol";

/**
 * @title DonationCommunity
 * @dev Manages donations and owns a charity vault
 * Aware of the EthKidsRegistry and passes a part of donations to the whole community
 * The 'admin' is the community leader
 * The 'whitelisted' account is the EthKidsRegistry and must be specified
 * prior to adding to the EthKidsRegistry
 */
contract DonationCommunity is IDonationCommunity, RegistryAware, WhitelistedRole {
    using SafeMath for uint256;

    uint256 public constant CHARITY_DISTRIBUTION = 90; //%, the rest funds bonding curve

    string private _name;
    CharityVault public charityVault;

    RegistryInterface public registry;

    event LogDonationReceived
    (
        address from,
        uint256 amount
    );
    event LogPassToCharity
    (
        address by,
        address intermediary,
        uint256 amount,
        string ipfsHash
    );

    /**
    * @dev not allowed, can't store ETH
    **/
    function() external {
        //no 'payable' here
    }

    /**
    * @dev Constructor
    * @param name for reference
    */
    constructor (string memory name) public {
        _name = name;
        charityVault = new CharityVault();
    }

    function setRegistry(address _registry) public onlyWhitelisted {
        registry = (RegistryInterface)(_registry);
        charityVault.setRegistry(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

    function allocate(uint256 donation) internal pure returns (uint256 _charityAllocation, uint256 _bondingAllocation) {
        uint256 _multiplier = 100;
        _charityAllocation = (donation).mul(CHARITY_DISTRIBUTION).div(_multiplier);
        _bondingAllocation = donation.sub(_charityAllocation);
        return (_charityAllocation, _bondingAllocation);
    }

    function myReward(uint256 _ethAmount) public view returns (uint256 tokenAmount) {
        (uint256 _charityAllocation, uint256  _bondingAllocation) = allocate(_ethAmount);
        return getRegistry().getBondingVault().calculateReward(_bondingAllocation, msg.sender);
    }

    function myReturn(uint256 _tokenAmount) public view returns (uint256 returnEth) {
        return getRegistry().getBondingVault().calculateReturn(_tokenAmount, msg.sender);
    }

    function donate() public payable {
        donateDelegated(msg.sender);
    }

    /**
    * @dev Donate funds on behalf of someone else.
    * Primary use is to pass the actual donor when the caller is a proxy, like KyberConverter
    * @param _donor address that will be recorded as a donor and will receive the community tokens
    **/
    function donateDelegated(address payable _donor) public payable {
        require(msg.value > 0, "Must include some ETH to donate");

        (uint256 _charityAllocation, uint256  _bondingAllocation) = allocate(msg.value);
        charityVault.deposit.value(_charityAllocation)(_donor);

        getRegistry().getBondingVault().fundWithAward.value(_bondingAllocation)(_donor);

        emit LogDonationReceived(_donor, msg.value);
    }

    function passToCharity(uint256 _amount, address payable _intermediary, string memory _ipfsHash) public onlyWhitelistAdmin {
        require(_intermediary != address(0));
        charityVault.withdraw(_intermediary, _amount);
        emit LogPassToCharity(msg.sender, _intermediary, _amount, _ipfsHash);
    }

    function name() public view returns (string memory) {
        return _name;
    }


}
