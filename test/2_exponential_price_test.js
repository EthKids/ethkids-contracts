var ExponentialDeflation = artifacts.require("ExponentialDeflation");


contract('ExponentialPrice', async (accounts) => {

    let formula;
    let TOKEN_MINTED = web3.utils.toWei('100', 'ether');
    let CURVE_RESERVE = web3.utils.toWei('100', 'ether');

    before("run initial setup ", async () => {
        console.log(`Starting ExponentialDeflation...`);

        formula = await ExponentialDeflation.new();
    })

    it("can calculate CHANCE amount for personal holdings 1%-100%", async () => {
        for (let i = 1; i < 100; i++) {
            const buying = await formula.calculatePurchaseReturn(
                TOKEN_MINTED,                                   //total supply
                web3.utils.toWei(i.toString(), 'ether'),        //personal CHANCE holdings
                CURVE_RESERVE,
                web3.utils.toWei('1', 'ether'));                //amount ETH paying
            //console.log((buying/(Number)(web3.utils.toWei('1', 'ether'))).toString());
        }
    })

    it("can calculate ETH return for personal holdings 1%-100%", async () => {
        for (let i = 1; i < 100; i++) {
            const selling = await formula.calculateSaleReturn(
                TOKEN_MINTED,                                   //total supply
                web3.utils.toWei(i.toString(), 'ether'),        //personal CHANCE holdings
                CURVE_RESERVE,
                web3.utils.toWei('1', 'ether'));                //amount CHANCE selling
            const liquidatedForEth = selling / (Number)(web3.utils.toWei('1', 'ether'));
            //console.log(liquidatedForEth.toString());
        }
    })

})