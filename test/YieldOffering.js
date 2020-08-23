const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time } = require('@openzeppelin/test-helpers');

const [starter, staker1, staker2] = accounts;

const YO = contract.fromArtifact('YieldOffering');
const MockWETH = contract.fromArtifact('MockWETH');

describe('Yield Offering', function() {
  beforeEach(async function() {
    const currentTime = await time.latest();
    const dt = new BN('5000');
    const initialWethSupply = new BN(`${10 * 10**18}`);
    const initialHourlySupply = new BN(`${1000 * 10**18}`);

    this.yieldRewardStakeToken = await MockWETH.new(initialWethSupply, { from: starter });

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

  });

  describe('initialization', function(){
    it('should properly initialize Stake Pools with a decay of 1 order of magnitude', async function() {
      const result = await this.yieldOffering.method.pools(1);
      expect(result).to.be.true;
    });
  });
});
