const truffleAssert = require('truffle-assertions');

var BondingVault = artifacts.require("BondingVault");
var CharityVault = artifacts.require("CharityVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var CommunityToken = artifacts.require("CommunityToken");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");

contract('EthKids', async (accounts) => {

    const ipfsMessage = "ipfsMessage_placeholder";

    let registry;
    let community;
    let bondingVault;
    let charityVault;
    let token;

    let OWNER = accounts[0];
    let DONATOR = accounts[1];
    let DONATOR2 = accounts[2];
    let EXTRA_OWNER = accounts[3];
    let CHARITY_INTERMEDIARY = accounts[4];

    let readableETH = function (wei) {
        return parseFloat(web3.utils.fromWei(wei.toString())).toFixed(3) + ' ETH';
    }

    let readableTokens = function (wei) {
        return parseFloat(web3.utils.fromWei(wei.toString())).toFixed(3) + ' CHANCE';
    }


    before("run initial setup ", async () => {
        console.log(`Starting EthKids...`);

        registry = await EthKidsRegistry.deployed();

        assert.strictEqual((await registry.communityIndex.call()).toString(), "1");

        community = await DonationCommunity.at(await registry.getCommunityAt(0));

        bondingVault = await BondingVault.at(await community.bondingVault.call());

        charityVault = await CharityVault.at(await community.charityVault.call());

        token = await CommunityToken.at(await community.getCommunityToken());
        assert.isTrue(await token.isMinter(bondingVault.address));

    })

    it("should be able to donate", async () => {
        await community.donate({from: DONATOR, value: web3.utils.toWei('1', 'ether')});

        console.log("(1) First donator, got in tokens: " +
            readableTokens(await token.balanceOf(DONATOR), {from: DONATOR}));

        console.log("(1) First donator, liquidation value ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONATOR), {from: DONATOR})).amountOfEth));

        //charity fund
        let charityAfter = (await web3.eth.getBalance(charityVault.address)).toString();
        assert.strictEqual(charityAfter, web3.utils.toWei("900", "finney"));
        //personal stats
        let stats = (await charityVault.depositsOf(DONATOR)).toString();
        assert.strictEqual(stats, web3.utils.toWei("900", "finney"));
        //global stats
        let globalStats = (await charityVault.sumStats.call()).toString();
        assert.strictEqual(globalStats, web3.utils.toWei("900", "finney"));


        //bonding curve fund
        let bondingCurveAfter = (await web3.eth.getBalance(bondingVault.address)).toString();
        assert.strictEqual(bondingCurveAfter, web3.utils.toWei("100", "finney"));

        //token minted
        assert.strictEqual((await token.totalSupply()).toString(), '788696680600241560'); //~0.78 CHANCE
    })

    it("should sum up on second donation", async () => {
        await community.donate({from: DONATOR2, value: web3.utils.toWei('2', 'ether')});

        console.log("(1) First donator, liquidation value after another donator ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONATOR), {from: DONATOR}))[1]));

        console.log("(2) Second donator, got in tokens: " +
            readableTokens(await token.balanceOf(DONATOR2), {from: DONATOR2}));

        console.log("(2) Second donator, liquidation value ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONATOR2), {from: DONATOR2})).amountOfEth));

        //charity fund
        let charityAfter = (await web3.eth.getBalance(charityVault.address)).toString();
        assert.strictEqual(charityAfter, web3.utils.toWei("2700", "finney"));
        //personal stats
        let stats = (await charityVault.depositsOf(DONATOR2)).toString();
        assert.strictEqual(stats, web3.utils.toWei("1800", "finney"));
        //global stats
        let globalStats = (await charityVault.sumStats.call()).toString();
        assert.strictEqual(globalStats, web3.utils.toWei("2700", "finney"));


        //bonding curve fund
        let bondingCurveAfter = (await web3.eth.getBalance(bondingVault.address)).toString();
        assert.strictEqual(bondingCurveAfter, web3.utils.toWei("300", "finney"));

        //token minted
        assert.strictEqual((await token.totalSupply()).toString(), '1388696680600241560'); //~1.38 CHANCE
    })

    it("should calculate return on sell", async () => {
        let testTokenAmount = web3.utils.toWei("100", "finney");
        let priceSmallDonator = (await community.myReturn(testTokenAmount, {from: DONATOR}))[0];
        let priceBigDonator = (await community.myReturn(testTokenAmount, {from: DONATOR2}))[0];

        console.log("(3) Donators comparison, buy/sell price for small: " + readableETH(priceSmallDonator));
        console.log("(3) Donators comparison, buy/sell price for big: " + readableETH(priceBigDonator));

        let priceSmallDonatorByOwner = (await community.returnForAddress(testTokenAmount, DONATOR))[0];
        assert.strictEqual(priceSmallDonatorByOwner.toString(), priceSmallDonator.toString());
    })

    it("should be able to sell", async () => {
        let donatorBalanceBefore = Number(await web3.eth.getBalance(DONATOR));
        let bondingVaultBalanceBefore = Number(await web3.eth.getBalance(bondingVault.address));
        let priceBeforeSell = (await community.myReturn(web3.utils.toWei("100", "finney"), {from: DONATOR}))[0];
        let expectedRemainingAfterSell = '288696680600241560'; //~0.28 CHANCE
        let expectedTotalSupplyAfterSell = '888696680600241560' //~0.88 CHANCE
        await community.sell(web3.utils.toWei("500", "finney"), {from: DONATOR});//0.5 CHANCE

        //personal ETH balance increased
        assert.isTrue(donatorBalanceBefore < Number(await web3.eth.getBalance(DONATOR)));
        //bonding curve ETH balance decreased
        assert.isTrue(bondingVaultBalanceBefore > Number(await web3.eth.getBalance(bondingVault.address)));
        //personal CHANCE balance decreased
        assert.strictEqual(expectedRemainingAfterSell, (await token.balanceOf(DONATOR)).toString());
        //total supply decreased
        assert.strictEqual((await token.totalSupply()).toString(), expectedTotalSupplyAfterSell);

        let priceAfterSell = (await community.myReturn(web3.utils.toWei("100", "finney"), {from: DONATOR}))[0];
        console.log("(4) My price before I sell: " + readableETH(priceBeforeSell));
        console.log("(4) My price after I sold: " + readableETH(priceAfterSell));
    })

    it("should be able to pass to charity", async () => {
        let charityFundBefore = Number(await web3.eth.getBalance(charityVault.address));
        let intermediaryBalanceBefore = Number(await web3.eth.getBalance(CHARITY_INTERMEDIARY));

        let tx = await community.passToCharity(web3.utils.toWei("1", "ether"), CHARITY_INTERMEDIARY, ipfsMessage);

        assert.strictEqual(Number(await web3.eth.getBalance(charityVault.address)) + Number(web3.utils.toWei("1", "ether")),
            charityFundBefore);
        assert.strictEqual(Number(await web3.eth.getBalance(CHARITY_INTERMEDIARY)) - Number(web3.utils.toWei("1", "ether")),
            intermediaryBalanceBefore);

        truffleAssert.eventEmitted(tx, 'LogPassToCharity', (ev) => {
            return ev.by === OWNER && ev.intermediary === CHARITY_INTERMEDIARY
                && ev.amount.toString() === web3.utils.toWei("1", "ether") && ev.ipfsHash === ipfsMessage;
        }, 'LogPassToCharity should be emitted with correct parameters');

    })

    it("should be able to sweep the bonding curve vault", async () => {
        //sell all
        await community.sell(await token.balanceOf(DONATOR), {from: DONATOR});//
        await community.sell(await token.balanceOf(DONATOR2), {from: DONATOR2});//

        assert.strictEqual((await token.totalSupply()).toString(), "0");
        console.log("Vault after all sells: " + readableETH(await web3.eth.getBalance(bondingVault.address)));

        //bad guy can't
        try {
            await community.sweepBondingVault({from: DONATOR});
            assert.ok(false, 'not authorized!');
        } catch (error) {
            assert.ok(true, 'expected');
        }

        await community.sweepBondingVault();
    })

    it("should be able to add an extra community leader", async () => {
        assert.strictEqual(await community.isSigner(EXTRA_OWNER), false);

        await community.addSigner(EXTRA_OWNER);
        assert.strictEqual(await community.isSigner(EXTRA_OWNER), true);
    })

    it("new community leader can pass to charity", async () => {
        //bad guy can't
        try {
            await community.passToCharity(web3.utils.toWei("1", "ether"), CHARITY_INTERMEDIARY, ipfsMessage, {from: CHARITY_INTERMEDIARY});
            assert.ok(false, 'not authorized!');
        } catch (error) {
            assert.ok(true, 'expected');
        }
        await community.passToCharity(web3.utils.toWei("1", "ether"), CHARITY_INTERMEDIARY, ipfsMessage, {from: EXTRA_OWNER});
    })

    it("new leader can renounce from community", async () => {
        await community.renounceSigner({from: EXTRA_OWNER});
        assert.strictEqual(await community.isSigner(EXTRA_OWNER), false);
    })

})