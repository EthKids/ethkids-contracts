var BancorFormula = artifacts.require("BancorFormula");
var BondingVault = artifacts.require("BondingVault");
var YieldVault = artifacts.require("YieldVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");
var KyberConverter = artifacts.require("KyberConverter");
var ERC20Mintable = artifacts.require("ERC20Mintable");

const empty_address = '0x0000000000000000000000000000000000000000';
const initialTokenMint = web3.utils.toWei("1000000", "ether"); //1.000.000 CHANCE, required for initial 'sell price' calculation
const initialValueFunding = web3.utils.toWei("10", "finney"); //0.01 ETH, required for initial liquidation calculation
const tokenName = 'Chance';
const tokenSym = 'CHANCE';


async function deployCommunity(deployer, name, registryAddress) {
    await deployer.deploy(DonationCommunity, name);
    const communityInstance = await DonationCommunity.deployed();
    await communityInstance.addWhitelisted(registryAddress);
    return communityInstance;
}

function getKyberForNetwork(network, accounts) {
    if (network == 'development') {
        return {
            kyberNetworkAddress: empty_address,
            feeWallet: empty_address,
        }
    } else if (network == 'rinkeby') {
        return {
            kyberNetworkAddress: '0xF77eC7Ed5f5B9a5aee4cfa6FFCaC6A4C315BaC76',
            feeWallet: empty_address,
        }
    } else if (network == 'ropsten') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: empty_address,
        }
    } else if (network == 'live') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: '0xDdC0E4931936d9F590Ccb29f7f4758751479d0A8',
        }
    }
}

module.exports = async function (deployer, network, accounts) {

    let registryInstance;
    let kyberConverterInstance;

    console.log(`  === Deploying EthKids contracts to ${network}...`);
    let {kyberNetworkAddress, feeWallet} = getKyberForNetwork(network, accounts)

    console.log(`  Deploying bonding vault...`);
    await deployer.deploy(BancorFormula);
    const bondingFormulaInstance = await BancorFormula.deployed();
    console.log('EthKids, BancorFormula: NEW ' + bondingFormulaInstance.address);

    await deployer.deploy(BondingVault, tokenName, tokenSym, bondingFormulaInstance.address,
        initialTokenMint, {value: initialValueFunding});
    const bondingVaultInstance = await BondingVault.deployed();
    console.log('EthKids, BondingVault: NEW ' + bondingVaultInstance.address);

    await deployer.deploy(YieldVault);
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
    kyberConverterInstance = await deployer.deploy(KyberConverter, kyberNetworkAddress, feeWallet);
    console.log('EthKids, KyberConverter: NEW ' + kyberConverterInstance.address);
    console.log(`  Registering converter in the registry...`);
    await registryInstance.registerCurrencyConverter(kyberConverterInstance.address);


    ///////////////
    // This is to run by a community leader
    console.log(`  Deploying a community ChanceBY...`);
    let communityInstance1 = await deployCommunity(deployer, 'ChanceBY', registryInstance.address);
    console.log('EthKids, DonationCommunity: NEW ' + communityInstance1.address);

    console.log(`  Deploying a community Kika...`);
    let communityInstance2 = await deployCommunity(deployer, 'Kika', registryInstance.address);
    console.log('EthKids, DonationCommunity: NEW ' + communityInstance2.address);

    console.log(`  Deploying a community BySol...`);
    let communityInstance3 = await deployCommunity(deployer, 'BySol', registryInstance.address);
    console.log('EthKids, DonationCommunity: NEW ' + communityInstance3.address);
    ///////////////

    console.log(`  Registering communities in the registry...`);
    await registryInstance.registerCommunity(communityInstance1.address);
    await registryInstance.registerCommunity(communityInstance2.address);
    await registryInstance.registerCommunity(communityInstance3.address);

    console.log('DONE migration');
}