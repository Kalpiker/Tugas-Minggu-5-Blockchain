// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Registrasi Hak Cipta Karya Multimedia (Updated)
/// @notice Mengelola pencatatan hak cipta digital berbasis IPFS dengan kontrol akses dan transfer kepemilikan
contract MediaCopyrightRegistry {

    // Custom Error untuk efisiensi Gas
    error UnauthorizedAccess(address caller);
    error MediaAlreadyExists(bytes32 mediaId);
    error MediaNotFound(bytes32 mediaId);

    enum MediaType { Image, Audio, Video, Model3D }

    // Struct metadata karya multimedia dengan penambahan histori kepemilikan
    struct MediaWork {
        bytes32 mediaId;
        string title;
        string ipfsHash;
        MediaType mediaType;
        address creator;             // Pencipta asli karya
        address currentOwner;        // Pemilik hak cipta saat ini
        uint256 timestamp;
        bool isVerified;
        address[] ownershipHistory;  // Histori perubahan kepemilikan
    }

    address public admin;

    // Storage mappings
    mapping(bytes32 => MediaWork) private registry;
    mapping(address => bytes32[]) private ownerPortfolio; // Portfolio berdasarkan pemilik saat ini

    // Events
    event MediaRegistered(bytes32 indexed mediaId, address indexed creator, string ipfsHash);
    event MediaVerified(bytes32 indexed mediaId, address indexed verifier);
    event CopyrightTransferred(bytes32 indexed mediaId, address indexed oldOwner, address indexed newOwner);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedAccess(msg.sender);
        _;
    }

    modifier onlyCurrentOwner(bytes32 _mediaId) {
        if (registry[_mediaId].currentOwner != msg.sender) revert UnauthorizedAccess(msg.sender);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @dev Mendaftarkan hak cipta media baru
    function registerMedia(
        string calldata _title,
        string calldata _ipfsHash,
        MediaType _mediaType
    ) external returns (bytes32) {
        require(bytes(_title).length > 0, "Judul tidak boleh kosong");
        require(bytes(_ipfsHash).length > 0, "IPFS Hash wajib diisi");

        bytes32 mediaId = keccak256(abi.encodePacked(msg.sender, _ipfsHash, block.timestamp));

        if (registry[mediaId].timestamp != 0) revert MediaAlreadyExists(mediaId);

        MediaWork storage newWork = registry[mediaId];
        newWork.mediaId = mediaId;
        newWork.title = _title;
        newWork.ipfsHash = _ipfsHash;
        newWork.mediaType = _mediaType;
        newWork.creator = msg.sender;
        newWork.currentOwner = msg.sender;
        newWork.timestamp = block.timestamp;
        newWork.isVerified = false;
        newWork.ownershipHistory.push(msg.sender);

        ownerPortfolio[msg.sender].push(mediaId);

        emit MediaRegistered(mediaId, msg.sender, _ipfsHash);
        return mediaId;
    }

    /// @dev Memindahkan hak kepemilikan karya multimedia (Tugas 1 & 2)
    function transferCopyright(bytes32 _mediaId, address _newOwner) external onlyCurrentOwner(_mediaId) {
        require(_newOwner != address(0), "Alamat penerima tidak valid");
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);

        address oldOwner = registry[_mediaId].currentOwner;
        
        // Memperbarui pemilik saat ini
        registry[_mediaId].currentOwner = _newOwner;
        
        // Menyimpan histori perubahan kepemilikan
        registry[_mediaId].ownershipHistory.push(_newOwner);

        // Memperbarui portfolio pemilik
        _removeFromPortfolio(oldOwner, _mediaId);
        ownerPortfolio[_newOwner].push(_mediaId);

        emit CopyrightTransferred(_mediaId, oldOwner, _newOwner);
    }

    /// @dev Fungsi internal untuk menghapus mediaId dari portfolio pemilik lama
    function _removeFromPortfolio(address _owner, bytes32 _mediaId) internal {
        bytes32[] storage portfolio = ownerPortfolio[_owner];
        for (uint256 i = 0; i < portfolio.length; i++) {
            if (portfolio[i] == _mediaId) {
                portfolio[i] = portfolio[portfolio.length - 1];
                portfolio.pop();
                break;
            }
        }
    }

    /// @dev Verifikasi karya oleh Admin
    function verifyMedia(bytes32 _mediaId) external onlyAdmin {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        registry[_mediaId].isVerified = true;

        emit MediaVerified(_mediaId, msg.sender);
    }

    /// @dev Membaca metadata media (Read-Only / Gasless)
    function getMedia(bytes32 _mediaId) external view returns (MediaWork memory) {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        return registry[_mediaId];
    }

    /// @dev Mengambil daftar ID karya milik pemilik saat ini
    function getOwnerPortfolio(address _owner) external view returns (bytes32[] memory) {
        return ownerPortfolio[_owner];
    }

    /// @dev Mengambil histori kepemilikan suatu karya
    function getOwnershipHistory(bytes32 _mediaId) external view returns (address[] memory) {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        return registry[_mediaId].ownershipHistory;
    }
}