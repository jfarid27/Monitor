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
    const dt = 5000;
    this.yieldRewardStakeToken = await MockWETH.new(10 * 10**18, { from: starter });
    this.yieldOffering = await YO.new(
      currentTime,
      currentTime + 2 * dt,
      currentTime + 3 * dt,
      currentTime + 4 * dt,
      currentTime + 5 * dt,
      currentTime + 6 * dt,
      currentTime + 7 * dt,
      currentTime + 8 * dt,
      1000 * 10**18,
      yieldRewardStakeToken,
    {
      from: starter
    });
  });

  describe('initialization', function(){
    it('should properly initialize Stake Pools with a decay of 1 order of magnitude', function() {
      expect(this.yieldOffering.method.pools(1)).to.be.true;
    });
  });
});
