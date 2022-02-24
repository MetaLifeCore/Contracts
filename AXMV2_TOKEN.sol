// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AXMV2 is ERC20, Ownable {
    using SafeMath for uint256;
    uint256 private constant preMineSupply = 700000000 * 1e18;
    uint256 private minSupply = 50000000 * 1e18;
    // uint256 private constant maxSupply = 1000000000 * 1e18;     // the total supply

    using EnumerableSet for EnumerableSet.AddressSet;
    // minters managers
    EnumerableSet.AddressSet private _minters;
    // _dao_governance list
    EnumerableSet.AddressSet private _dao_governance_list;
    // _dao_manage list
    EnumerableSet.AddressSet private _dao_manage_list;
    // Pair address, in this enumerable we will draw transaction fee
    EnumerableSet.AddressSet private _pairlist;
    // the addtess to receive the fee
    address private _reward;
    // fee rate 10000 = 100%

    // all rate 10000 = 100%
    uint256 private in_burn_rate = 200;
    uint256 private in_reward_rate = 300;
    uint256 private out_burn_rate = 200;
    uint256 private out_reward_rate = 300;

    // transfer status
    // 0 allow all user transfer without _dao_governance list
    // 1 stop all transfer
    // 2 only _dao_manage list can transfer
    uint256 private _transfer_status;

    constructor() ERC20("AMM eXplorer Metalife V2", "AXMV2"){
        _transfer_status = 0;
        EnumerableSet.add(_minters, msg.sender);
        EnumerableSet.add(_dao_manage_list, msg.sender);
        _reward = msg.sender;
        _mint(msg.sender, preMineSupply);
        in_burn_rate = 0;
        in_reward_rate = 0;
        out_burn_rate = 0;
        out_reward_rate = 0;
    }

    // mint with max supply
    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        // if (_amount.add(totalSupply()) > maxSupply) {
        //     return false;
        // }
        // require(_amount.add(totalSupply()) <= maxSupply, "AXMV2: mint amount over max allow");
        _mint(_to, _amount);
        return true;
    }

    function addMinter(address _addMinter) public onlyOwner returns (bool) {
        require(_addMinter != address(0), "AXMV2: _addMinter is the zero address");
        require(is_dao_governance(_addMinter) == false, "AXMV2: _addMinter is the _dao_governancelist address");
        return EnumerableSet.add(_minters, _addMinter);
    }

    function delMinter(address _delMinter) public onlyOwner returns (bool) {
        require(_delMinter != msg.sender, "AXMV2: _delMinter is the owner address");
        return EnumerableSet.remove(_minters, _delMinter);
    }

    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    function getMinter(uint256 _index) public view onlyOwner returns (address){
        require(_index + 1 <= getMinterLength(), "AXMV2: index out of bounds");
        return EnumerableSet.at(_minters, _index);
    }

    // modifier for mint function
    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

    // burn with mine supply
    function burn(address _to, uint256 _amount) public onlyMinter returns (bool) {
        _burn(_to, _amount);
        return true;
    }

    // _dao_governance list
    function add_dao_governance(address _add_dao_governance) public onlyMinter returns (bool) {
        require(_add_dao_governance != owner(), "AXMV2: _add_dao_governance is the owner address");
        if (is_dao_manage(_add_dao_governance)) {
            del_dao_manage(_add_dao_governance);
        }
        if (isMinter(_add_dao_governance)) {
            del_dao_manage(_add_dao_governance);
        }
        return EnumerableSet.add(_dao_governance_list, _add_dao_governance);
    }

    function del_dao_governance(address _del_dao_governance) public onlyMinter returns (bool) {
        return EnumerableSet.remove(_dao_governance_list, _del_dao_governance);
    }

    function get_dao_governanceLength() public view returns (uint256) {
        return EnumerableSet.length(_dao_governance_list);
    }

    function is_dao_governance(address account) public view returns (bool) {
        return EnumerableSet.contains(_dao_governance_list, account);
    }

    function get_dao_governance(uint256 _index) public view onlyMinter returns (address){
        require(_index + 1 <= get_dao_governanceLength(), "AXMV2: index out of bounds");
        return EnumerableSet.at(_dao_governance_list, _index);
    }

    // _dao_manage list
    function add_dao_manage(address _add_dao_manage) public onlyMinter returns (bool) {
        require(_add_dao_manage != address(0), "AXMV2: _add_dao_manage is the zero address");
        if (is_dao_governance(_add_dao_manage)) {
            del_dao_governance(_add_dao_manage);
        }
        return EnumerableSet.add(_dao_manage_list, _add_dao_manage);
    }

    function del_dao_manage(address _del_dao_manage) public onlyMinter returns (bool) {
        require(_del_dao_manage != owner(), "AXMV2: _del_dao_manage is the owner address");
        return EnumerableSet.remove(_dao_manage_list, _del_dao_manage);
    }

    function get_dao_manageLength() public view returns (uint256) {
        return EnumerableSet.length(_dao_manage_list);
    }

    function is_dao_manage(address account) public view returns (bool) {
        return EnumerableSet.contains(_dao_manage_list, account);
    }

    function get_dao_manage(uint256 _index) public view onlyMinter returns (address){
        require(_index + 1 <= get_dao_manageLength(), "AXMV2: index out of bounds");
        return EnumerableSet.at(_dao_manage_list, _index);
    }

    // Set transfer status
    function setStatus(uint256 _status) public onlyMinter {
        require(_status < 3, "AXMV2: status is not allow");
        _transfer_status = _status;
    }

    // burn
    function _burn(address account, uint256 amount) internal override virtual {
        uint256 total_supply = totalSupply();
        if (total_supply.sub(amount) < minSupply) {
            in_burn_rate = 0;
            in_reward_rate = 0;
            out_burn_rate = 0;
            out_reward_rate = 0;
        }
        else {
            super._burn(account, amount);
        }
    }

    function getMinSupply() public view onlyMinter returns (uint256) {
        return minSupply;
    }

    function setMinSupply(uint256 _minSupply) public onlyMinter {
        require(_minSupply <= totalSupply(), "AXMV2: set minSupply less than total supply");
        minSupply = _minSupply;
    }

    function getInBurnRate() public view onlyMinter returns (uint256) {
        return in_burn_rate;
    }

    function setInBurnRate(uint256 _in_burn_rate) public onlyMinter {
        require((_in_burn_rate + in_reward_rate) <= 10000, "AXMV2: set in burn rate out of max rate");
        in_burn_rate = _in_burn_rate;
    }

    function getInRewardRate() public view onlyMinter returns (uint256) {
        return in_reward_rate;
    }

    function setInRewarcRate(uint256 _in_reward_rate) public onlyMinter {
        require((in_burn_rate + _in_reward_rate) <= 10000, "AXMV2: set in reward rate out of max rate");
        in_reward_rate = _in_reward_rate;
    }

    function getOutBurnRate() public view onlyMinter returns (uint256) {
        return out_burn_rate;
    }

    function setOutBurnRate(uint256 _out_burn_rate) public onlyMinter {
        require((_out_burn_rate + in_reward_rate) <= 10000, "AXMV2: set out burn rate out of max rate");
        out_burn_rate = _out_burn_rate;
    }

    function getOutRewardRate() public view onlyMinter returns (uint256) {
        return out_reward_rate;
    }

    function setOutRewardRate(uint256 _out_reward_rate) public onlyMinter {
        require((out_burn_rate + _out_reward_rate) <= 10000, "AXMV2: set out reward rate out of max rate");
        out_reward_rate = _out_reward_rate;
    }

    // transfer
    function _transfer(address sender, address recipient, uint256 amount) internal override virtual {
        require(_transfer_status != 1, "AXMV2: All transactions have been prohibited");
        require(is_dao_governance(sender) == false, "AXMV2: _dao_governance_list have been prohibited");
        require(is_dao_governance(recipient) == false, "AXMV2: _dao_governance_list have been prohibited");
        if (_transfer_status == 2) {
            require(is_dao_manage(sender), "AXMV2: Only allow _dao_manage_list to initiate transactions ");
        }
        uint256 burn_fee = 0;
        uint256 reward_fee = 0;
        if (isPair(sender)) {
            burn_fee = amount.div(10000).mul(out_burn_rate);
            reward_fee = amount.div(10000).mul(out_reward_rate);
        }
        if (isPair(recipient)) {
            burn_fee = amount.div(10000).mul(in_burn_rate);
            reward_fee = amount.div(10000).mul(in_reward_rate);
        }
        amount = amount.sub(burn_fee).sub(reward_fee);
        if (burn_fee > 0) _burn(sender, burn_fee);
        if (reward_fee > 0) super._transfer(sender, _reward, reward_fee);

        super._transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal override virtual {
        require(is_dao_governance(owner) == false, "AXMV2: _dao_governancelist have been prohibited");
        require(is_dao_governance(spender) == false, "AXMV2: _dao_governancelist have been prohibited");
        super._approve(owner, spender, amount);
    }

    // pair list
    function addPair(address _addPair) public onlyMinter returns (bool) {
        require(_addPair != address(0), "AXMV2: _addPair is the zero address");
        if (is_dao_governance(_addPair)) {
            del_dao_governance(_addPair);
        }
        return EnumerableSet.add(_pairlist, _addPair);
    }

    function delPair(address _delPair) public onlyMinter returns (bool) {
        require(_delPair != owner(), "AXMV2: _delPair is the owner address");
        return EnumerableSet.remove(_pairlist, _delPair);
    }

    function getPairLength() public view returns (uint256) {
        return EnumerableSet.length(_pairlist);
    }

    function isPair(address account) public view returns (bool) {
        return EnumerableSet.contains(_pairlist, account);
    }

    function getPair(uint256 _index) public view onlyMinter returns (address){
        require(_index <= getPairLength() - 1, "AXMV2: index out of bounds");
        return EnumerableSet.at(_pairlist, _index);
    }

    function setReward(address account) public onlyMinter returns (bool) {
        require(is_dao_governance(account) == false, "AXMV2: _dao_governancelist have been prohibited");
        _reward = account;
        return true;
    }

    function isContract(address _token) public view returns (bool) {
        uint256 pay_size = 0;
        assembly { pay_size := extcodesize(_token) }
        return pay_size > 0;
    }

    function transferToken(address _token, address recipient, uint256 amount) public onlyOwner {
        require(recipient != address(0), "AXMV2: recipient is zero address");
        if (_token == address(0)) {
            require(address(this).balance >= amount, "AXMV2: amount over balance");
            payable(recipient).transfer(amount);
        } // main coin
        else {
            require(isContract(_token), "AXMV2: _token is not contract address");
            require(IERC20(_token).balanceOf(address(this)) >= amount, "AXMV2: amount over balance");
            SafeERC20.safeTransfer(IERC20(_token), recipient, amount);
        }
    }
}
