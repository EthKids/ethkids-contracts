var ExponentialDeflation = artifacts.require("ExponentialDeflation");
var BondingVault = artifacts.require("BondingVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");
var KyberConverter = artifacts.require("KyberConverter");

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
            stableToken: empty_address,
        }
    } else if (network == 'rinkeby') {
        return {
            kyberNetworkAddress: '0xF77eC7Ed5f5B9a5aee4cfa6FFCaC6A4C315BaC76',
            feeWallet: empty_address,
            stableToken: '0x6FA355a7b6bD2D6bD8b927C489221BFBb6f1D7B2', //KNC
        }
    } else if (network == 'ropsten') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: empty_address,
            stableToken: '0xaD6D458402F60fD3Bd25163575031ACDce07538D', //DAI
        }
    } else if (network == 'live') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: '0xDdC0E4931936d9F590Ccb29f7f4758751479d0A8',
            stableToken: '0x6b175474e89094c44da98b954eedeac495271d0f', //DAI
            //stableToken: '0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359', //SAI
        }
    }
}

module.exports = async function (deployer, network, accounts) {

    let chanceByCommunityInstance;
    let registryInstance;
    let kyberConverterInstance;

    console.log(`  === Deploying EthKids contracts to ${network}...`);

    console.log(`  Deploying bonding vault...`);
    await deployer.deploy(ExponentialDeflation);
    const bondingFormulaInstance = await ExponentialDeflation.deployed();
    console.log('EthKids, ExponentialDeflation: NEW ' + bondingFormulaInstance.address);
    await deployer.deploy(BondingVault, tokenName, tokenSym, bondingFormulaInstance.address,
        initialTokenMint, {value: initialValueFunding});
    const bondingVaultInstance = await BondingVault.deployed();
    console.log('EthKids, BondingVault: NEW ' + bondingVaultInstance.address);

    console.log(`  Deploying EthKidsRegistry...`);
    await deployer.deploy(EthKidsRegistry, bondingVaultInstance.address);
    registryInstance = await EthKidsRegistry.deployed();
    await bondingVaultInstance.addWhitelistAdmin(registryInstance.address);
    await bondingVaultInstance.setRegistry(registryInstance.address);
    console.log('EthKids, EthKidsRegistry: NEW ' + registryInstance.address);

    console.log(`  Deploying dedicated Kyber converter...`);
    const {kyberNetworkAddress, feeWallet, stableToken} = getKyberForNetwork(network, accounts)
    kyberConverterInstance = await deployer.deploy(KyberConverter, kyberNetworkAddress, feeWallet, stableToken);
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