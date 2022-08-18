// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

contract PieceOfShit is ERC2981, ERC721AQueryable, Ownable {
    using Address for address payable;
    using Strings for uint256;

    event LuckyShit(address minter, uint32 amount);

    bytes32 public immutable _lotterySalt; // 彩票的盐值？？
    uint256 public immutable _price;
    uint32 public immutable _maxSupply;
    uint32 public immutable _teamSupply;
    uint32 public immutable _instantFreeSupply; // 立即免费的数量？？
    uint32 public immutable _randomFreeSupply;  // 随机免费的数量？？
    uint32 public immutable _instantFreeWalletLimit; 
    uint32 public immutable _walletLimit;

    uint32 public _teamMinted;
    uint32 public _randomFreeMinted;
    uint32 public _instantFreeMinted;
    bool public _started;
    string public _metadataURI = "https://metadata.pieceofshit.wtf/json/";

    struct Status {
        // config
        uint256 price;
        uint32 maxSupply;  // 10,000
        uint32 publicSupply;  // 
        uint32 instantFreeSupply;
        uint32 randomFreeSupply;
        uint32 instantFreeWalletLimit;
        uint32 walletLimit;

        // state
        uint32 publicMinted;
        uint32 instantFreeMintLeft;
        uint32 randomFreeMintLeft;
        uint32 userMinted;
        bool soldout;
        bool started;
    }

    constructor(
        uint256 price,
        uint32 maxSupply,
        uint32 teamSupply,
        uint32 instantFreeSupply,
        uint32 randomFreeSupply,
        uint32 instantFreeWalletLimit,
        uint32 walletLimit
    ) ERC721A("pieceofshit", "SHIT") { // 合约名称，合约简称
        require(maxSupply >= teamSupply + instantFreeSupply);
        require(maxSupply - teamSupply - instantFreeSupply >= randomFreeSupply);

        _lotterySalt = keccak256(abi.encodePacked(address(this), block.timestamp)); // ??? 1,当前地址和当前区块链时间戳哈希成一个bytes32
        _price = price;
        _maxSupply = maxSupply;
        _teamSupply = teamSupply;
        _instantFreeSupply = instantFreeSupply;
        _instantFreeWalletLimit = instantFreeWalletLimit;
        _randomFreeSupply = randomFreeSupply;
        _walletLimit = walletLimit;

        setFeeNumerator(750); // ??? 2，设置免费数量？
    }

    function mint(uint32 amount) external payable {
        require(_started, "PieceOfShit: Sale is not started");

        uint32 publicMinted = _publicMinted(); // 公开minted = 已经mint-团队mint
        uint32 publicSupply = _publicSupply(); // 公开supply = 总supply-团队supply 
        require(amount + publicMinted <= _publicSupply(), "PieceOfShit: Exceed max supply");

        uint32 minted = uint32(_numberMinted(msg.sender));
        require(amount + minted <= _walletLimit, "PieceOfShit: Exceed wallet limit"); // 每个钱包最多mint限制

        uint32 instantFreeWalletLimit = _instantFreeWalletLimit;
        uint32 freeAmount = 0;
        if (minted < instantFreeWalletLimit) {
            uint32 quota = instantFreeWalletLimit - minted;
            freeAmount += quota > amount ? amount : quota;
        }
 
        if (minted + amount > instantFreeWalletLimit) {
            uint32 enterLotteryAmount = amount - instantFreeWalletLimit;
            uint32 randomFreeAmount = 0;
            uint32 randomFreeMinted = _randomFreeMinted;
            uint32 quota = _randomFreeSupply - randomFreeMinted;
            // 随机免费，会把钱返还，重点
            if (quota > 0) {
                uint256 randomSeed = uint256(keccak256(abi.encodePacked(
                    msg.sender,
                    publicMinted,
                    block.difficulty,
                    _lotterySalt))); // 随机数种子
                    
                for (uint256 i = 0; i < enterLotteryAmount && quota > 0; ) {
                    if (uint16((randomSeed & 0xFFFF) % publicSupply) < quota) {
                        randomFreeAmount += 1;
                        quota -= 1;
                    }

                    unchecked {
                        i++;
                        randomSeed = randomSeed >> 16;
                    }
                }

                if (randomFreeAmount > 0) {
                    freeAmount += randomFreeAmount;
                    _randomFreeMinted += randomFreeAmount;
                    emit LuckyShit(msg.sender, randomFreeAmount);
                }
            }
        }
        // 检查钱够不够
        uint256 requiredValue = (amount - freeAmount) * _price;
        require(msg.value >= requiredValue, "PieceOfShit: Insufficient fund");

        _safeMint(msg.sender, amount);
        if (msg.value > requiredValue) { // 把钱返还
            payable(msg.sender).sendValue(msg.value - requiredValue);
        }
    }

    function _publicMinted() public view returns (uint32) { // 总公开minted
        return uint32(_totalMinted()) - _teamMinted;
    }

    function _publicSupply() public view returns (uint32) {  // 总公开supply
        return _maxSupply - _teamSupply;
    }

    function _status(address minter) external view returns (Status memory) {  // 查看状态参数
        uint32 publicSupply = _maxSupply - _teamSupply;
        uint32 publicMinted = uint32(ERC721A._totalMinted()) - _teamMinted;

        return Status({
            // config
            price: _price,
            maxSupply: _maxSupply,
            publicSupply:publicSupply,
            instantFreeSupply: _instantFreeSupply,
            randomFreeSupply: _randomFreeSupply,
            instantFreeWalletLimit: _instantFreeWalletLimit,
            walletLimit: _walletLimit,

            // state
            publicMinted: publicMinted,
            instantFreeMintLeft: _instantFreeSupply - _instantFreeMinted,
            randomFreeMintLeft: _randomFreeSupply - _randomFreeMinted,
            soldout:  publicMinted >= publicSupply,
            userMinted: uint32(_numberMinted(minter)),
            started: _started
        });
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) { // 重写721a，查看单个tokenURI，给opensea看的，后面需要加.json，721a不需要
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken(); //不存在就抛出异常

        string memory baseURI = _metadataURI;
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981, ERC721A) returns (bool) { // 支持接口，应该是屎怪调用的
        return
            interfaceId == type(IERC2981).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function devMint(address to, uint32 amount) external onlyOwner { // 团队mint
        _teamMinted += amount;
        require(_teamMinted <= _teamSupply, "PieceOfShit: Exceed max supply");
        _safeMint(to, amount);
    }

    function setFeeNumerator(uint96 feeNumerator) public onlyOwner {  // ？？？ 3，设置免费的数量？Numerator分子
        _setDefaultRoyalty(owner(), feeNumerator);
    }

    function setStarted(bool started) external onlyOwner { // 公售开关
        _started = started;
    }

    function setMetadataURI(string memory uri) external onlyOwner { // 设置metadataURI
        _metadataURI = uri;
    }

    function withdraw() external onlyOwner { // 取钱
        payable(msg.sender).sendValue(address(this).balance);
    }
}