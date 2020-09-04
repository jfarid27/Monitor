// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "./ERC1155.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";


contract ERC1155withAdapter is ERC1155 {
    mapping(uint256 => address) public adapter;

    mapping(uint256 => uint256) public totalSupply;

    address public template;

    event NewAdapter(uint256 indexed id, address indexed adapter);

    constructor(string memory uri) public ERC1155(uri) {
        template = address(new ERC20Adapter());
    }

    function createAdapter(uint256 _id, string memory _name, string memory _symbol, uint8 _decimals) public {
        require(adapter[_id] == address(0));
        address a = createClone(template);
        ERC20Adapter(a).setup(_id, _name, _symbol, _decimals);
        adapter[_id] = a;
        emit NewAdapter(_id, a);
    }

    function transferByAdapter(address _from, address _to, uint256 _id, uint256 _value) public returns(bool) {
        require(adapter[_id] == msg.sender);

        // SafeMath will throw with insuficient funds _from
        // or if _id is not valid (balance will be 0)
        _balances[_id][_from] = _balances[_id][_from].sub(_value);
        _balances[_id][_to] = _value.add(_balances[_id][_to]);

        bytes memory _data;

        if (_to.isContract()) {
            if (ERC165(_from).supportsInterface(0x4e2312e0)) {
                _doSafeTransferAcceptanceCheck(_from, _from, _to, _id, _value, _data);
            }
        }

        // MUST emit event
        emit TransferSingle(msg.sender, _from, _to, _id, _value);
        return true;
    }

    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
                mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
                mstore(add(clone, 0x14), targetBytes)
                mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
                result := create(0, clone, 0x37)
        }
    }

}


contract ERC20Adapter {
    using SafeMath for uint256;

    ERC1155withAdapter public entity;

    uint256 public id;
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping (address => mapping (address => uint256)) private allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(entity.transferByAdapter(msg.sender, recipient, id, amount));
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        allowed[sender][msg.sender] = allowed[sender][msg.sender].sub(amount);
        require(entity.transferByAdapter(sender, recipient, id, amount));
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function totalSupply() external view returns (uint256) {
        return entity.totalSupply(id);
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256) {
        return entity.balanceOf(account, id);
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return allowed[owner][spender];
    }

    /**
     * @dev setup the adapter, use as a constructor.
     */
    function setup(uint256 _id, string memory _name, string memory _symbol, uint8 _decimals) public {
        require(id == 0 && address(entity) == address(0));
        entity = ERC1155withAdapter(msg.sender);
        id = _id;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

}
