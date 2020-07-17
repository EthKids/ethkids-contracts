var ExponentialDeflation = artifacts.require("ExponentialDeflation");
var BondingVault = artifacts.require("BondingVault");
var YieldVault = artifacts.require("YieldVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");
var KyberConverter = artifacts.require("KyberConverter");
var ERC20Mintable = artifacts.require("ERC20Mintable");

const empty_address = '0x0000000000000000000000000000000000000000';
const initialTokenMint = web3.utils.toWei("1", "ether"); //1 CHANCE, required for initial 'sell price' calculation
const initialValueFunding = web3.utils.toWei("100", "finney"); //0.1 ETH, required for initial liquidation calculation
const tokenName = 'Chance';
const tokenSym = 'CHANCE';


async function deployCommunity(deployer, name, registryAddress) {
    await deployer.deploy(DonationCommunity, name);
    const communityInstance = await DonationCommunity.deployed();
    await communityInstance.addWhitelisted(registryAddress);
    return communityInstance;
}

async function deployChanceBy(deployer, registryAddress) {
    return await deployCommunity(deployer, 'ChanceBY', registryAddress);
}

function getKyberForNetwork(network, accounts) {
    if (network == 'development') {
        return {
            kyberNetworkAddress: empty_address,
            feeWallet: empty_address,
            dai: empty_address,
            aDai: empty_address,
        }
    } else if (network == 'rinkeby') {
        return {
            kyberNetworkAddress: '0xF77eC7Ed5f5B9a5aee4cfa6FFCaC6A4C315BaC76',
            feeWallet: empty_address,
            dai: '0x6FA355a7b6bD2D6bD8b927C489221BFBb6f1D7B2', //KNC
            aDai: empty_address,
        }
    } else if (network == 'ropsten') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: empty_address,
            dai: '0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108', //DAI, compartible with KyberSwap and Aave
            aDai: '0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201',
        }
    } else if (network == 'live') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: '0xDdC0E4931936d9F590Ccb29f7f4758751479d0A8',
            dai: '0x6b175474e89094c44da98b954eedeac495271d0f', //DAI
            //dai: '0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359', //SAI
            aDai: '0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d',
        }
    }
}

module.exports = async function (deployer, network, accounts) {

    let chanceByCommunityInstance;
    let registryInstance;
    let kyberConverterInstance;

    console.log(`  === Deploying EthKids contracts to ${network}...`);
    let {kyberNetworkAddress, feeWallet, dai, aDai} = getKyberForNetwork(network, accounts)

    console.log(`  Deploying bonding vault...`);
    await deployer.deploy(ExponentialDeflation);
    const bondingFormulaInstance = await ExponentialDeflation.deployed();
    console.log('EthKids, ExponentialDeflation: NEW ' + bondingFormulaInstance.address);

    await deployer.deploy(BondingVault, tokenName, tokenSym, bondingFormulaInstance.address,
        initialTokenMint, {value: initialValueFunding});
    const bondingVaultInstance = await BondingVault.deployed();
    console.log('EthKids, BondingVault: NEW ' + bondingVaultInstance.address);

    if (aDai === empty_address) {
        // deploy a mock of an aToken
        await deployer.deploy(ERC20Mintable);
        const aTokenInstance = await ERC20Mintable.deployed();
        aDai = aTokenInstance.address;
    }
    await deployer.deploy(YieldVault, aDai, dai);
    const yieldVaultInstance = await YieldVault.deployed();
    console.log('EthKids, YieldVault: NEW ' + yieldVaultInstance.address);

    console.log(`  Deploying EthKidsRegistry...`);
    await deployer.deploy(EthKidsRegistry, bondingVaultInstance.address, yieldVaultInstance.address);
    registryInstance = await EthKidsRegistry.deployed();
    await bondingVaultInstance.addWhitelistAdmin(registryInstance.address);
    await bondingVaultInstance.setRegistry(registryInstance.address);
    await yieldVaultInstance.addWhitelistAdmin(registryInstance.address);
    await yieldVaultInstance.setRegistry(registryInstance.address);
    console.log('EthKids, EthKidsRegistry: NEW ' + registryInstance.address);

    console.log(`  Deploying dedicated Kyber converter...`);
    kyberConverterInstance = await deployer.deploy(KyberConverter, kyberNetworkAddress, feeWallet, dai);
    console.log('EthKids, KyberConverter: NEW ' + kyberConverterInstance.address);
    console.log(`  Registering converter in the registry...`);
    await registryInstance.registerCurrencyConverter(kyberConverterInstance.address);


    ///////////////
    // This is to run by a community leader
    console.log(`  Deploying ChanceBy community...`);
    chanceByCommunityInstance = await deployChanceBy(deployer, registryInstance.address);
    console.log('EthKids, DonationCommunity: NEW ' + chanceByCommunityInstance.address);
    ///////////////

    console.log(`  Registering community in the registry...`);
    await registryInstance.registerCommunity(chanceByCommunityInstance.address);

    console.log('DONE migration');
}