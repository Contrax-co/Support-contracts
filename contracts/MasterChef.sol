// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IContraxMintableERC20.sol";

interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}

contract MasterChef is Ownable {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accCoinPerShare;
    }
    IContraxMintableERC20 public coin;
    address public devaddr;
    uint256 public bonusEndBlock;
    uint256 public coinPerBlock;
    uint256 public constant BONUS_MULTIPLIER = 10;
    IMigratorChef public migrator;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        address _coin,
        address _devaddr,
        uint256 _coinPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ){
        coin = IContraxMintableERC20(_coin);
        devaddr = _devaddr;
        coinPerBlock = _coinPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        transferOwnership(_devaddr);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + (_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accCoinPerShare: 0
            })
        );
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - (poolInfo[_pid].allocPoint)+(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.approve(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return (_to - _from) * (BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to - (_from);
        } else {
            return
                ((bonusEndBlock - _from) * BONUS_MULTIPLIER) + (
                    _to - (bonusEndBlock)
                );
        }
    }

    function pendingCoin(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCoinPerShare = pool.accCoinPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 coinReward =
                ((multiplier * coinPerBlock) * pool.allocPoint) / (
                    totalAllocPoint
                );
            accCoinPerShare = (accCoinPerShare + 
                (coinReward * 1e12) / (lpSupply)
            );
        }
        return ((user.amount * accCoinPerShare) / 1e12) - (user.rewardDebt);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 coinReward =
            (((multiplier * coinPerBlock) * pool.allocPoint) / 
                totalAllocPoint
            );
        coin.mint(devaddr, coinReward / 10);
        coin.mint(address(this), coinReward);
        pool.accCoinPerShare = (pool.accCoinPerShare + 
            (coinReward * 1e12) / (lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                (((user.amount * pool.accCoinPerShare) / 1e12) - 
                    user.rewardDebt
                );
            safeCoinTransfer(msg.sender, pending);
        }
        pool.lpToken.transferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount + (_amount);
        user.rewardDebt = ((user.amount * pool.accCoinPerShare) / 1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            (((user.amount * pool.accCoinPerShare) / 1e12) - 
                user.rewardDebt
            );
        safeCoinTransfer(msg.sender, pending);
        user.amount = user.amount - (_amount);
        user.rewardDebt = (user.amount * pool.accCoinPerShare) / 1e12;
        pool.lpToken.transfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function safeCoinTransfer(address _to, uint256 _amount) internal {
        uint256 coinBal = coin.balanceOf(address(this));
        if (_amount > coinBal) {
            coin.transfer(_to, coinBal);
        } else {
            coin.transfer(_to, _amount);
        }
    }

    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
