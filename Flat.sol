// File: @openzeppelin/contracts/utils/Context.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/IStaking.sol

pragma solidity ^0.8.0;

interface IStaking {
    function getStakedAmount() external view returns(uint256);
    function getAccountInfo(address staker) external view returns (uint256, uint256, uint256);
}

// File: contracts/LessLibrary.sol


pragma solidity ^0.8.0;



contract LessLibrary is Ownable {
    address[] private presaleAddresses; // track all presales created

    uint256 private minInvestorBalance = 15000 * 1e18;
    uint256 private votingTime = 600; //tthree days
    //uint256 private votingTime = 300;
    uint256 private minStakeTime = 300; //one day
    uint256 private minUnstakeTime = 1000; //six days

    address private factoryAddress;

    uint256 private minVoterBalance = 500 * 1e18; // minimum number of  tokens to hold to vote
    uint256 private minCreatorStakedBalance = 8000 * 1e18; // minimum number of tokens to hold to launch rocket

    uint8 private feePercent = 2;

    address private uniswapRouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // uniswapV2 Router

    address payable private lessVault;
    address private devAddress;
    IStaking public safeStakingPool;

    mapping(address => bool) private isPresale;

    modifier onlyDev() {
        require(owner() == msg.sender || msg.sender == devAddress, "onlyDev");
        _;
    }

    modifier onlyPresale() {
        require(isPresale[msg.sender], "Not presale");
        _;
    }

    modifier onlyFactory() {
        require(factoryAddress == msg.sender, "onlyFactory");
        _;
    }

    constructor(address _dev, address payable _vault) {
        require(_dev != address(0));
        require(_vault != address(0));
        devAddress = _dev;
        lessVault = _vault;
    }

    function setFactoryAddress(address _factory) external onlyDev {
        require(_factory != address(0));
        factoryAddress = _factory;
    }

    function addPresaleAddress(address _presale)
        external
        onlyFactory
        returns (uint256)
    {
        presaleAddresses.push(_presale);
        isPresale[_presale] = true;
        return presaleAddresses.length - 1;
    }

    function getPresalesCount() external view returns (uint256) {
        return presaleAddresses.length;
    }

    function getPresaleAddress(uint256 id) external view returns (address) {
        return presaleAddresses[id];
    }

    function setPresaleAddress(uint256 id, address _newAddress)
        external
        onlyDev
    {
        presaleAddresses[id] = _newAddress;
    }

    function setVotingTime(uint256 _newVotingTime) external onlyDev {
        require(_newVotingTime > 0, "Wrong new time");
        votingTime = _newVotingTime;
    }

    function setStakingAddress(address _staking) external onlyDev {
        require(_staking != address(0));
        safeStakingPool = IStaking(_staking);
    }

    function getVotingTime() public view returns(uint256){
        return votingTime;
    }

    function getMinInvestorBalance() external view returns (uint256) {
        return minInvestorBalance;
    }

    function getMinUnstakeTime() external view returns (uint256) {
        return minUnstakeTime;
    }

    function getDev() external view onlyFactory returns (address) {
        return devAddress;
    }

    function getMinVoterBalance() external view returns (uint256) {
        return minVoterBalance;
    }

    function getMinYesVotesThreshold() external view returns (uint256) {
        uint256 stakedAmount = safeStakingPool.getStakedAmount();
        return stakedAmount / 10;
    }

    function getFactoryAddress() external view returns (address) {
        return factoryAddress;
    }

    function getMinCreatorStakedBalance() external view returns (uint256) {
        return minCreatorStakedBalance;
    }

    function getStakedSafeBalance(address sender)
        public
        view
        returns (uint256)
    {
        uint256 balance;
        uint256 lastStakedTimestamp;
        (balance, lastStakedTimestamp, ) = safeStakingPool.getAccountInfo(
            address(sender)
        );

        if (lastStakedTimestamp + minStakeTime <= block.timestamp) {
            return balance;
        }
        return 0;
    }

    function getUniswapRouter() external view returns (address) {
        return uniswapRouter;
    }

    function setUniswapRouter(address _uniswapRouter) external onlyDev {
        uniswapRouter = _uniswapRouter;
    }

    function calculateFee(uint256 amount) external view onlyPresale returns(uint256){
        return amount * feePercent / 100;
    }

    function getVaultAddress() external view onlyPresale returns(address payable){
        return lessVault;
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol



pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol



pragma solidity ^0.8.0;


/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol



pragma solidity ^0.8.0;




/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The defaut value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol



pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: contracts/interface.sol


pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IUniswapV2Factory02 {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

// File: contracts/PresalePublic.sol


pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import "./Staking.sol";



contract PresalePublic is ReentrancyGuard {
    //initial values
    address payable presaleCreator;
    address platformOwner;
    address private devAddress;
    IERC20 public token;
    uint8 public tokenDecimals;
    uint256 public pricePerToken;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public closeTimeVoting;
    uint256 public openTimePresale;
    uint256 public closeTimePresale;
    uint8 public liquidityAllocation;
    uint256 public listingPrice;
    uint256 public liquidityLockDuration;
    uint256 public liquidityAllocationTime;
    address private lpAddress;
    uint256 private lpAmount;
    //uint256 public minEthPerWallet;
    //uint256 public ethAllocationFactor;
    uint256 public unlockEthTime; // time when presale creator can collect funds raise
    //uint256 public headStart;
    uint256 public tokenMagnitude = 1e18;
    uint256 public minInvestInWei; // minimum wei amount that can be invested per wallet address
    uint256 public maxInvestInWei; // maximum wei amount that can be invested per wallet address
    uint256 private presaleId;

    //presale values
    bool cancelled;
    bool liquidityAdded;
    uint256 public raisedAmount;
    uint256 public participants;
    address factoryAddress;
    uint256 public yesVotes;
    uint256 public noVotes;
    uint256 public tokensLeft; // available tokens to be sold
    uint256 public tokensForLiquidity;
    uint256 private counter;
    mapping(address => uint256) public voters;
    mapping(address => bool) public claimed; // if true, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address

    //stringInfo
    bytes32 public saleTitle;
    bytes32 public linkTelegram;
    bytes32 public linkTwitter;
    bytes32 public linkGithub;
    bytes32 public linkWebsite;
    string public linkLogo;
    string public description;
    string public whitepaper;

    //other contracts
    LessLibrary public lessLib;

    struct Investment {
        uint256 amountEth;
        uint256 amountTokens;
    }

    modifier onlyFabric() {
        require(factoryAddress == msg.sender);
        _;
    }

    modifier onlyPlatformOwner() {
        require(platformOwner == msg.sender);
        _;
    }

    modifier onlyWhenOpenVoting() {
        require(block.timestamp <= closeTimeVoting);
        _;
    }

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(nowTime >= openTimePresale && nowTime <= closeTimePresale);
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!cancelled);
        _;
    }

    modifier votesPassed() {
        require(
            yesVotes >= noVotes &&
                yesVotes >= lessLib.getMinYesVotesThreshold(),
            "Votes not passed"
        );
        _;
    }

    constructor(
        address _factory,
        address _library,
        address _platformOwner,
        address _devAddress
    ) {
        require(_factory != address(0));
        require(_library != address(0));
        require(_platformOwner != address(0));
        require(_devAddress != address(0));
        factoryAddress = _factory;
        lessLib = LessLibrary(_library);
        platformOwner = _platformOwner;
        devAddress = _devAddress;
        counter = 0;
        yesVotes = 0;
        noVotes = 0;
        raisedAmount = 0;
        participants = 0;
        lpAmount = 0;
        closeTimeVoting = block.timestamp + lessLib.getVotingTime();
        cancelled = false;
        liquidityAdded = false;
    }

    function init(
        address[2] memory _creatorToken,
        //address _presaleCreator,
        //address _token,
        uint256[5] memory _priceTokensForSaleLiquiditySoftHard,
        //uint256 _price,
        //uint256 _tokensForSale,
        //uint256 _tokensForLiquidity,
        //uint256 _soft,
        //uint256 _hard,
        uint8 _liquidityAlloc,
        uint256[5] memory _liqPriceDurationAllocTimeOpenClose
        //uint256 _listingPrice,
        //uint256 _liquidityLockDuration,
        //uint256 _liquidityAllocationTime,
        //uint256 _openPresale,
        //uint256 _closePresale
    ) external onlyFabric {
        require(_creatorToken[0] != address(0) && _creatorToken[1] != address(0), "Wrong addresses");
        require(counter == 0, "Function can work only once");
        require(_priceTokensForSaleLiquiditySoftHard[0] > 0, "Price should be more then zero");
        require(
            _liqPriceDurationAllocTimeOpenClose[3] > 0 && _liqPriceDurationAllocTimeOpenClose[4] > 0,
            "Wrong time presale interval"
        );
        require(_priceTokensForSaleLiquiditySoftHard[3] > 0 && _priceTokensForSaleLiquiditySoftHard[4] > 0, "Wron soft or hard cup values");
        require(
            _liqPriceDurationAllocTimeOpenClose[3] >= closeTimeVoting,
            "Voting and investment should not overlap"
        );
        require(
            _priceTokensForSaleLiquiditySoftHard[1] != 0 && _priceTokensForSaleLiquiditySoftHard[2] != 0,
            "Not null tokens amount"
        );
        require(
            _liquidityAlloc != 0 &&
                _liqPriceDurationAllocTimeOpenClose[1] != 0 &&
                _liqPriceDurationAllocTimeOpenClose[0] != 0,
            "Not null liquidity vars"
        );
        require(_liqPriceDurationAllocTimeOpenClose[2] > _liqPriceDurationAllocTimeOpenClose[4], "Wrong liquidity allocation time");
        presaleCreator = payable(_creatorToken[0]);
        token = IERC20(_creatorToken[1]);
        tokenDecimals = ERC20(_creatorToken[1]).decimals();
        pricePerToken = _priceTokensForSaleLiquiditySoftHard[0];
        softCap = _priceTokensForSaleLiquiditySoftHard[3];
        hardCap = _priceTokensForSaleLiquiditySoftHard[4];
        liquidityAllocation = _liquidityAlloc;
        listingPrice = _liqPriceDurationAllocTimeOpenClose[0];
        liquidityLockDuration = _liqPriceDurationAllocTimeOpenClose[1];
        liquidityAllocationTime = _liqPriceDurationAllocTimeOpenClose[2];
        tokensLeft = _priceTokensForSaleLiquiditySoftHard[1];
        tokensForLiquidity = _priceTokensForSaleLiquiditySoftHard[2];
        openTimePresale = _liqPriceDurationAllocTimeOpenClose[3];
        closeTimePresale = _liqPriceDurationAllocTimeOpenClose[4];
        tokenMagnitude = uint256(10)**uint256(tokenDecimals);
        counter++;
    }

    function vote(bool yes) external onlyWhenOpenVoting presaleIsNotCancelled {
        uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);

        require(
            safeBalance >= lessLib.getMinVoterBalance(),
            "Not enough Less to vote"
        );
        require(voters[msg.sender] == 0, "Vote already casted");

        voters[msg.sender] = safeBalance;
        if (yes) {
            yesVotes = yesVotes + safeBalance;
        } else {
            noVotes = noVotes + safeBalance;
        }
    }

    function invest()
        public
        payable
        presaleIsNotCancelled
        onlyWhenOpenPresale
        votesPassed
    {
        uint256 reservedTokens = getTokenAmount(msg.value);
        require(raisedAmount < hardCap, "Hard cap reached");
        require(tokensLeft >= reservedTokens);
        require(msg.value > 0);
        uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);
        require(
            msg.value <= (tokensLeft * pricePerToken) / tokenMagnitude,
            "Not enough tokens left"
        );
        uint256 totalInvestmentInWei = investments[msg.sender].amountEth + msg.value;
        require(
            totalInvestmentInWei >= minInvestInWei ||
                raisedAmount >= hardCap - 1 ether,
            "Min investment not reached"
        );
        require(
            maxInvestInWei == 0 || totalInvestmentInWei <= maxInvestInWei,
            "Max investment reached"
        );

        uint256 minInvestorBalance = lessLib.getMinInvestorBalance();
        require(
            minInvestorBalance == 0 || safeBalance >= minInvestorBalance,
            "Stake LessTokens"
        );

        if (investments[msg.sender].amountEth == 0) {
            participants += 1;
        }

        raisedAmount += msg.value;
        investments[msg.sender].amountEth = totalInvestmentInWei;
        investments[msg.sender].amountTokens += reservedTokens;
        tokensLeft = tokensLeft - reservedTokens;
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        votesPassed
    {
        require(block.timestamp >= openTimePresale, "Not yet opened");
        require(investments[msg.sender].amountEth != 0, "You are not an invesor");
        require(
            investments[msg.sender].amountEth >= amount,
            "You have not invest so much"
        );
        require(amount > 0, "Enter not zero amount");
        if (!cancelled) {
            require(
                raisedAmount < softCap,
                "Couldn't withdraw investments after softCap collection"
            );
        }
        //require(raisedAmount < softCap, "Couldn't withdraw investments after softCap collection");
        require(to != address(0), "Enter not a zero address");
        if (investments[msg.sender].amountEth - amount == 0) {
            participants -= 1;
        }
        to.transfer(amount);
        uint256 reservedTokens = getTokenAmount(amount);
        raisedAmount -= amount;
        investments[msg.sender].amountEth -= amount;
        investments[msg.sender].amountTokens -= reservedTokens;
        tokensLeft += reservedTokens;
    }

    function claimTokens() external nonReentrant {
        /*require(
            raisedAmount >= hardCap,
            "You can claim tokens after collection a hardCap"
        );*/
        require(liquidityAdded, "Liquidity is not provided");
        require(block.timestamp >= closeTimePresale, "Wait presale close time");
        require(investments[msg.sender].amountEth != 0, "You are not an invesor");
        require(
            !claimed[msg.sender],
            "You've been already claimed your tokens"
        );
        claimed[msg.sender] = true; // make sure this goes first before transfer to prevent reentrancy
        token.transfer(msg.sender, investments[msg.sender].amountTokens);
    }

    receive() external payable {
        invest();
    }

    function changeCloseTimeVoting(uint256 _newCloseTime) external presaleIsNotCancelled {
        require(msg.sender == platformOwner || msg.sender == presaleCreator);
        require(block.timestamp < openTimePresale, "Presale has already beginning");
        require(
            _newCloseTime <= openTimePresale,
            "Voting and investment should not overlap"
        );
        closeTimeVoting = _newCloseTime;
    }

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime) external presaleIsNotCancelled {
        require(msg.sender == platformOwner || msg.sender == presaleCreator);
        require(block.timestamp < openTimePresale, "Presale has already beginning");
        require(closeTimeVoting < _newOpenTime, "Wrong new open presale time");
        require(_newCloseTime > _newOpenTime, "Wrong new parameters");
        require(_newCloseTime < liquidityAllocationTime, "Wrong new close presale time");
        openTimePresale = _newOpenTime;
        closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator || msg.sender == platformOwner);
        cancelled = true;
    }

    function getPresaleId() external view returns (uint256) {
        return presaleId;
    }

    function setPresaleId(uint256 _id) external onlyFabric {
        presaleId = _id;
    }

    function setStringInfo(
        bytes32 _saleTitle,
        bytes32 _linkTelegram,
        bytes32 _linkGithub,
        bytes32 _linkTwitter,
        bytes32 _linkWebsite,
        string calldata _linkLogo,
        string calldata _description,
        string calldata _whitepaper
    ) external onlyFabric {
        saleTitle = _saleTitle;
        linkTelegram = _linkTelegram;
        linkGithub = _linkGithub;
        linkTwitter = _linkTwitter;
        linkWebsite = _linkWebsite;
        linkLogo = _linkLogo;
        description = _description;
        whitepaper = _whitepaper;
    }

    function addLiquidity() external presaleIsNotCancelled {
        require(msg.sender == devAddress, "Function is only for backend");
        require(liquidityAllocationTime <= block.timestamp, "Too early to adding liquidity");
        
        require(
            block.timestamp >= closeTimePresale,
            "Wait for presale closing"
        );
        require(!liquidityAdded, "Liquidity has been already added");
        require(raisedAmount > 0, "Have not raised amount");

        uint256 liqPoolEthAmount = (raisedAmount * liquidityAllocation) / 100;
        uint256 liqPoolTokenAmount =
            (liqPoolEthAmount * tokenMagnitude) / listingPrice;

        require(tokensForLiquidity >= liqPoolTokenAmount, "Error liquidity");

        IUniswapV2Router02 uniswapRouter =
            IUniswapV2Router02(address(lessLib.getUniswapRouter()));

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        ( , ,lpAmount) = uniswapRouter.addLiquidityETH{value: liqPoolEthAmount}(
            address(token),
            liqPoolTokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 15 minutes
        );

        require(lpAmount != 0, "lpAmount not null");

        IUniswapV2Factory02 uniswapFactory = IUniswapV2Factory02(uniswapRouter.factory());
        lpAddress = uniswapFactory.getPair(uniswapRouter.WETH(), address(token));

        tokensForLiquidity -= liqPoolTokenAmount;
        liquidityAdded = true;
        unlockEthTime =
            block.timestamp +
            (liquidityLockDuration * 24 * 60 * 60);
    }

    function collectFundsRaised() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator, "Function for presale creator");
        require(liquidityAdded, "Add liquidity to get raised funds");
        //require(block.timestamp >= unlockEthTime);

        uint256 collectedBalance = address(this).balance;

        if (collectedBalance > 0) {
            uint256 fee = lessLib.calculateFee(collectedBalance);
            //address payable vault = lessLib.getVaultAddress();
            lessLib.getVaultAddress().transfer(fee);
            presaleCreator.transfer(address(this).balance);
        }
    }

    function refundLpTokens() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator, "Function for presale creator");
        require(liquidityAdded, "Add liquidity to get raised funds");
        require(block.timestamp >= unlockEthTime, "Too early");
        require(IERC20(lpAddress).transfer(presaleCreator, lpAmount), "Couldn't get your tokens");
    }

    function getUnsoldTokens() external presaleIsNotCancelled{
        require(liquidityAdded);
        require(msg.sender == presaleCreator || msg.sender == platformOwner, "Only for owners");

        uint256 unsoldTokensAmount = tokensLeft + tokensForLiquidity;
        if (unsoldTokensAmount > 0) {
            token.transfer(presaleCreator, unsoldTokensAmount);
        }
    }

    function getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        uint256 amount = lessLib.getStakedSafeBalance(msg.sender);
        uint256 discount = 0;
        if (amount < 15000) {
            return (_weiAmount * tokenMagnitude) / pricePerToken;
        } else if (amount >= 15000 && amount < 75000) {
            return (_weiAmount * tokenMagnitude) / pricePerToken;
        } else if (amount >= 75000 && amount < 150000) {
            discount = (pricePerToken * 5) / 100;
            return (_weiAmount * tokenMagnitude) / (pricePerToken - discount);
        } else if (amount >= 150000 && amount < 325000) {
            discount = (pricePerToken * 7) / 100;
            return (_weiAmount * tokenMagnitude) / (pricePerToken - discount);
        } else if (amount >= 700000) {
            discount = pricePerToken / 10;
            return (_weiAmount * tokenMagnitude) / (pricePerToken - discount);
        }

        return 0;

        //uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);

        /*if (safeBalance >= minRewardQualifyBal) {
            uint256 pctQualifyingDiscount =
                tokenPriceInWei.mul(minRewardQualifyPercentage).div(100);
            return
                _weiAmount.mul(tokenMagnitude).div(
                    tokenPriceInWei.sub(pctQualifyingDiscount)
                );
        } else {
            return _weiAmount.mul(tokenMagnitude).div(tokenPriceInWei);
        }*/

        //return (_weiAmount * tokenMagnitude) / pricePerToken;
    }
}
