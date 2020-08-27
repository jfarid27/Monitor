const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time } = require('@openzeppelin/test-helpers');

const [starter, staker1, staker2] = accounts;

const YO = contract.fromArtifact('YieldOffering');
const SP = contract.fromArtifact('StakePool');
const Vision = contract.fromArtifact('Vision');
const MockWETH = contract.fromArtifact('MockWETH');

describe('Yield Offering', function() {
  beforeEach(async function() {
    const erc1820 = await singletons.ERC1820Registry(accounts[0]);
    const currentTime = await time.latest();
    this.currentTime = currentTime;
    const dt = new BN('5000');
    this.dt = dt;
    this.initialWethSupply = new BN(`${100 * 10**18}`);
    const initialHourlySupply = new BN(`${1 * 10**18}`);

    this.yieldRewardStakeToken = await MockWETH.new(this.initialWethSupply, { from: starter });
    this.yieldOffering = await YO.new(
      currentTime,
      currentTime.add((new BN('1')).mul(dt)),
      currentTime.add((new BN('2')).mul(dt)),
      currentTime.add((new BN('3')).mul(dt)),
      currentTime.add((new BN('4')).mul(dt)),
      currentTime.add((new BN('5')).mul(dt)),
      currentTime.add((new BN('6')).mul(dt)),
      currentTime.add((new BN('7')).mul(dt)),
      initialHourlySupply,
      this.yieldRewardStakeToken.address,
      {
        from: starter,
        gasLimit: 10000000,
        gasPrice: 100
      }
    );

    this.poolAddresses = await this.yieldOffering.getPoolAddresses();
    this.pool1 = await SP.at(this.poolAddresses[0]);

    this.visionAddress = await this.yieldOffering.mainTokenAddress();
    this.vision = await Vision.at(this.visionAddress);
  });

  it('should properly initialize Stake Pools with a decay of 1 order of magnitude', async function() {
    expect(this.poolAddresses.length).to.equal(4);
  });

  describe('when given tokens', function() {
    beforeEach(async function() {
      this.depositAmount = new BN(`${10 * 10**18}`);
      await this.yieldRewardStakeToken.approve(this.pool1.address, this.depositAmount, { from: starter })
      await this.pool1.deposit(this.depositAmount, { from: starter });

    });
    describe('during yield offering', function() {
      beforeEach(async function() {
        await time.increase(this.currentTime.add((new BN('0.5')).mul(this.dt)));
        await this.pool1.withdraw(this.depositAmount, { from: starter });
      });
      it('should properly allow withdraw', async function() {
        const currentBalance = await this.yieldRewardStakeToken.balanceOf(starter);
        expect(currentBalance.eq(this.initialWethSupply));
      });
      it('should correctly update yield balance', async function() {
        const expected = (new BN(`${1 * 10**18}`))
            .mul((new BN('0.5')).mul(this.dt))
            .mul(this.depositAmount);
        const currentBalance = await this.yieldOffering.balanceOf(starter);
        expect(expected.eq(currentBalance));
      });
      it('should allow withdraw of yield', async function() {
        const yieldedBalance = await this.yieldOffering.balanceOf(starter);
        await this.yieldOffering.redeem({ from: starter });
        const redeemedBalance = await this.vision.balanceOf(starter);
        expect(yieldedBalance.eq(redeemedBalance));
      });
    });
    describe('after yield offering is completed', function() {
      beforeEach(async function() {
        await time.increase(this.currentTime.add((new BN('1')).mul(this.dt)));
        await this.pool1.withdraw(this.depositAmount, { from: starter });
      });
      it('should properly allow withdraw', async function() {
        const currentBalance = await this.yieldRewardStakeToken.balanceOf(starter);
        expect(currentBalance.eq(this.initialWethSupply));
      });
      it('should correctly update yield balance', async function() {
        const expected = (new BN(`${1 * 10**18}`)).mul(this.dt).mul(this.depositAmount)
        const currentBalance = await this.yieldOffering.balanceOf(starter);
        expect(expected.eq(currentBalance));
      });
      it('should allow withdraw of yield', async function() {
        const yieldedBalance = await this.yieldOffering.balanceOf(starter);
        await this.yieldOffering.redeem({ from: starter });
        const redeemedBalance = await this.vision.balanceOf(starter);
        expect(yieldedBalance.eq(redeemedBalance));
      });
    });

  });



});
