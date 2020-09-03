const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time, expectRevert } = require('@openzeppelin/test-helpers');

const [ from, other ] = accounts;

const Vision = contract.fromArtifact('VisionTest');
const Monitor = contract.fromArtifact('Monitor');
const RealityMarket = contract.fromArtifact('RealityMarket');
const ForesightVault = contract.fromArtifact('ForesightVault');
const Foresight = contract.fromArtifact('Foresight');

describe('Monitor', function() {
  beforeEach(async function() {
    const erc1820 = await singletons.ERC1820Registry(accounts[0]);
    this.vision = await Vision.new({ from: from });
    this.monitor = await Monitor.new(this.vision.address, this.vision.address, { from });
    this.userBalance = new BN('5000');
    await this.vision.mint(this.userBalance, { from });
    await this.vision.mint(this.userBalance, { from: other })
  });
  describe('when a market is created', function() {
    beforeEach(async function() {
      const currentTime = await time.latest();
      this.currentTime = currentTime;
      this.dt = new BN('500000');
      this.stakeAmount = new BN('100');
      await this.vision.approve(this.monitor.address, this.stakeAmount, { from });
      this.marketTransaction = await this.monitor.createMarket(
        "Will the sky be blue tomorrow?",
        this.currentTime.add(this.dt),
        this.stakeAmount,
        { from, gasLimit: 10000000 }
      );
      this.marketAddress = this.marketTransaction.receipt.logs[0].args.created;
      this.market = await RealityMarket.at(this.marketAddress);
      await this.market.initializeVault({ from, gasLimit: 12000000 });
      await this.market.initializeVoting({ from });
      const foresightVaultAddress = await this.market.foresightVaultAddress();
      this.foresightVault = await ForesightVault.at(foresightVaultAddress);
      await this.foresightVault.createYes({ from });
      await this.foresightVault.createNo({ from });
      await this.foresightVault.createInvalid({ from });
      this.yesToken = await this.foresightVault.yesShortTokenAddress().then(Foresight.at);
      this.noToken = await this.foresightVault.noLongTokenAddress().then(Foresight.at);
      this.invToken = await this.foresightVault.invalidTokenAddress().then(Foresight.at);
    });
    it('should properly store market stake', async function() {
      const stake = await this.monitor.stakeForMarket.call(this.marketAddress);
      expect(this.stakeAmount.eq(stake)).to.be.ok;
    });
    it('should properly store market creator', async function() {
      const address = await this.monitor.ownerForMarket.call(this.marketAddress);
      expect(address).to.eq(from);
    });

    it('should correctly take the users stake', async function() {
      const bal = await this.vision.balanceOf.call(from);
      expect(this.userBalance.sub(this.stakeAmount).eq(bal)).to.be.ok;
    });
    it('should not allow market creators to remove their stake until market is completed', async function() {
      await expectRevert.unspecified(this.monitor.withdrawStake(this.marketAddress));
    });
    describe('market functions', function() {
      it('should allow users to mint foresight tokens');
      it('should allow users to stake on outcomes');
      it('should not allow users to withdraw outcome stake');
      it('should not allow users to withdraw foresight');
    });
    describe('when market is completed and not invalid', function() {
      it('should allow users to convert foresight to mint stake');
      it('should allow withdraws for correct outcomes');
      it('should not allow withrdraws on incorrect outcomes');
      it('should allow market creator to remove their stake');
    })
    describe('when market is completed and invalid', function() {
      it('should allow users to convert foresight to mint stake');
      it('should allow withdraws for correct outcomes');
      it('should not allow withrdraws on incorrect outcomes');
      it('should not allow market creator to remove their stake');
    })
  });
});
