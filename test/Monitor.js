const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time, expectRevert } = require('@openzeppelin/test-helpers');

const [ account1, account2 ] = accounts;

describe('Monitor', function() {
  beforeEach(async function() {
    const erc1820 = await singletons.ERC1820Registry(account1);
    const Monitor = contract.fromArtifact('Monitor');
    const Vision = contract.fromArtifact('Vision');
    const MockWeth = contract.fromArtifact('MockWeth');
    this.startingWeth = (new BN('10000'));
    this.weth = await MockWeth.new(this.startingWeth, { from: account1 });
    this.monitor = await Monitor.new(this.weth.address, { from: account1 });
    await this.monitor.initialize({ from: account1 });
    const visionAddress = await this.monitor.vision.call();
    this.vision = await Vision.at(visionAddress);

    /**
     * Sets up both accounts with vision using backed WETH.
     */
    this.generateVision = async function() {
      this.stakeAmount = this.startingWeth.div(new BN('2'));
      await this.weth.transfer(account2, this.stakeAmount, { from: account1 });
      await this.weth.approve(this.monitor.address, this.stakeAmount, { from: account1 });
      await this.weth.approve(this.monitor.address, this.stakeAmount, { from: account2 });
      const trans1 = await this.monitor.mintVision(this.stakeAmount, { from: account1 });
      const trans2 = await this.monitor.mintVision(this.stakeAmount, { from: account2 });
      return [trans1, trans2];
    };

    /**
     * Sets up both accounts with vision using backed WETH.
     */
    this.withdrawVision = async function() {
      this.withdrawAmount = this.startingWeth.div(new BN('2'));
      await this.vision.approve(this.monitor.address, this.withdrawAmount, { from: account1 });
      const trans1 = await this.monitor.burnVision(this.withdrawAmount, { from: account1 });
      return [trans1];
    };

    this.checkBalanceEqERC20 = async function (contract, address, expected) {
      const value = await contract.balanceOf(address, { from: address });
      return value.eq(expected);
    };
  });
  describe('Vision Bonding Curve', function() {
    describe('deposit stake for vision', function() {
      beforeEach(async function() {
        await this.generateVision();
      });
      it('should debit correct amount of stake token', async function() {
        const check1 = await this.checkBalanceEqERC20(this.weth, account1, new BN('0'));
        const check2 = await this.checkBalanceEqERC20(this.weth, account2, new BN('0'));
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
      it('should credit correct amount of Vision', async function() {
        const check1 = await this.checkBalanceEqERC20(this.vision, account1, this.stakeAmount);
        const check2 = await this.checkBalanceEqERC20(this.vision, account2, this.stakeAmount);
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
    });
    describe('withdrawing stake using vision', function() {
      beforeEach(async function() {
        await this.generateVision();
        await this.withdrawVision();
      });
      it('should debit correct amount of vision', async function() {
        const check1 = await this.checkBalanceEqERC20(this.vision, account1, new BN('0'));
        const check2 = await this.checkBalanceEqERC20(this.vision, account2, this.stakeAmount);
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
      it('should credit correct amount of stake token', async function() {
        const check1 = await this.checkBalanceEqERC20(this.weth, account1, this.stakeAmount);
        const check2 = await this.checkBalanceEqERC20(this.weth, account2, new BN('0'));
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
    });
  });
});
