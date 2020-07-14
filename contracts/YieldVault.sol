pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./aave/IAToken.sol";
import "./RegistryAware.sol";
import "./ERC20.sol";

contract YieldVault is RegistryAware, WhitelistedRole {

    using SafeMath for uint256;
    RegistryInterface public registry;
    mapping(address => uint256) public withdrawalBacklog;

    constructor (address _registry) public {
        setRegistry(_registry);
    }

    function balance(address _atoken) public view returns (uint256) {
        return IAToken(_atoken).balanceOf(address(this));
    }

    function historicBalance(address _atoken) public view returns (uint256) {
        return balance(_atoken).add(withdrawalBacklog[_atoken]);
    }

    /**
    * @dev Msg.sender triggers the withdrawal from Aave, the DAI will be moved to the caller
    * Usually called from the CharityVault
    **/
    function withdraw(address _token, address _atoken, uint _amount) public onlyWhitelisted {
        address _user = msg.sender;

        //if not used as a collateral
        IAToken aToken = IAToken(_atoken);
        require(aToken.isTransferAllowed(address(this), _amount));
        aToken.redeem(_amount);
        withdrawalBacklog[_atoken] = withdrawalBacklog[_atoken].add(_amount);

        // return erc we have to the sender
        ERC20(_token).transfer(_user, _amount);
    }

    function setRegistry(address _registry) public onlyWhitelistAdmin {
        registry = (RegistryInterface)(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

}
