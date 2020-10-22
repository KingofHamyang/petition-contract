pragma solidity >=0.1.1 <=0.5.0;
pragma experimental ABIEncoderV2;

// Caller
contract Petition{
  // 국민 청원 내용
  struct Content {
    string title;
    string content;
    uint256 vote;
    uint256 start_time;
    string reply_url;
    bool is_replied;
    string category;
    bool is_block;
    string blocked_reason;
  }

  struct JuryPanel {
    address addr;
    uint256 dislike;
    uint256 like;
  }

  address owner;  // 청원 관리자
  uint256 id;  // 청원 index
  uint256 NUM_JURY;
  mapping(bytes32=>bool) votecheck;  // 해당 청원에 vote 했는지 여부 저장
  mapping(bytes32=>bool) juryvotecheck;
  mapping(uint256=>Content) petitions;  // 청원 저장
  mapping(address=>JuryPanel) jury_panels;
  mapping(address=>uint256[]) blocking_list;
  address[] jury_address;
  bool debugmode;
  uint[] return_indexes;
  uint256 criteria_vote = 100;

  modifier isJuryPanel(address _addr) {
    // emit Alert(msg.sender, functionname);
    require(jury_panels[_addr].like > 0, "The address of the arguments is not in jury pannel list.");
    // require(jury_panels[_addr].dislike < criteria_vote + 1, "This jury panel has over 100 dislikes.");
    _;
  }

  modifier voteChecker(uint256 _id) {  // 사용자가 이미 투표를 했는지 확인
    bytes32 addrhash = keccak256(toBytes(msg.sender));
    bytes32 idhash = keccak256(abi.encodePacked(_id));
    bytes32 checkhash = keccak256(abi.encodePacked(addrhash ^ idhash));
    require(!votecheck[checkhash], "This petition is already voted by msg.sender");
    votecheck[checkhash] = true;
    _;
  }

  modifier juryVoteChecker(address jury){  // 사용자가 이미 투표를 했는지 확인
    bytes32 senderhash = keccak256(toBytes(msg.sender));
    bytes32 juryhash = keccak256(toBytes(jury));
    bytes32 checkhash = keccak256(abi.encodePacked(juryhash ^ senderhash));
    require(!juryvotecheck[checkhash], "This jury is already evaluated by msg.sender");
    juryvotecheck[checkhash] = true;
    _;
  }

  modifier isOwner() {  // 청원 관리자 확인
    require(msg.sender == owner, "msg.sender is not the owner");
    _;
  }

  constructor() public {
    owner = msg.sender;
    debugmode = true;
    NUM_JURY = 0;
    id = 0;
  }

  function applyJury() public {
    require(msg.sender != owner, "msg.sender is the government account.");
    require(jury_panels[msg.sender].like == 0, "You are already in jury panel list.");
    require(NUM_JURY <= 100, "No vacancy for jury panel");
    jury_panels[msg.sender].dislike = 1;
    jury_panels[msg.sender].like = 1;
    jury_panels[msg.sender].addr = msg.sender;
    jury_address.push(msg.sender);
    NUM_JURY++;
  }

  function blockingContent(uint256 _id, string memory _blocked_reason) public isJuryPanel(msg.sender) {
    petitions[_id].is_block = true;
    petitions[_id].blocked_reason = _blocked_reason;
    blocking_list[msg.sender].push(_id);
  }

  function vote(uint256 _id) public voteChecker(_id) {  // 투표하기, did&중복투표 체크함
    require(!petitions[_id].is_block, "This petition is blocked");
    petitions[_id].vote += 1;
  }

  function write(string memory title, string memory content) public {  // 청원 작성
    petitions[id].title = title;
    petitions[id].content = content;

    petitions[id].vote = 0;
    petitions[id].start_time = block.timestamp;
    petitions[id].is_replied = false;
    id++;
  }

  function viewContent(uint256 _id) external view returns(string memory, string memory, uint256, uint256, string memory, string memory, string memory) {  // 청원 내용 불러오기
    require(_id < id, "doesn't exist.");
    return  ( petitions[_id].title,
              petitions[_id].content,
              petitions[_id].vote,
              petitions[_id].start_time,
              petitions[_id].reply_url,
              petitions[_id].category,
              petitions[_id].blocked_reason
            );
  }

  function getLastIndex() external view returns(uint256) {  // 마지막 index 보기
    require(id > 0, "No petition exists.");
    return id - 1;
  }

  function reply(uint256 _id, string memory url) public isOwner()  {  // 청원에 답변한 url 달기
    petitions[_id].reply_url = url;
    petitions[_id].is_replied = true;
  }

  function toBytes(address addr) private pure returns(bytes memory) {  // address type을 bytes type으로 바꾸기 (hashing 용)
    bytes memory byteaddr = new bytes(20);
    for (uint8 i = 0; i < 20; i++) {
      byteaddr[i] = byte(uint8(uint(addr) / (2**(8*(19 - i)))));
    }
    return (byteaddr);
  }

  function evaluateJury(address jury, bool isLike) public isJuryPanel(jury) juryVoteChecker(jury) {
    if (isLike) jury_panels[jury].like++;
    else {
      jury_panels[jury].dislike++;
      if (jury_panels[jury].dislike > criteria_vote + 1) {
        delete jury_panels[jury];
        NUM_JURY--;

        for (uint i = 0; i < jury_address.length; i++){
          if (jury_address[i] == jury) {
            delete jury_address[i];
            break;
          }
        }
      }
    }
  }

  function getBlockingListOfJury(address jury) external view returns(uint256[] memory){
    uint256[] memory temp_blocking_list = new uint256[](blocking_list[jury].length);
    uint i;
    for(i=0; i <blocking_list[jury].length ; i++){
      temp_blocking_list[i] = blocking_list[jury];
    }
    return temp_blocking_list;

  }
  
  function getJuryList() external view returns(address[] memory, uint[] memory, uint[] memory) {  // 판정단 list 불러오기
    address[] memory address_list = new address[](NUM_JURY);
    uint256[] memory like_list = new uint256[](NUM_JURY);
    uint256[] memory dislike_list = new uint256[](NUM_JURY);

    uint i;
    uint index = 0;
    for(i = 0; i < jury_address.length; i++){
      if(jury_address[i] != address(0)){
        address_list[index] = jury_address[i];
        dislike_list[index] = jury_panels[jury_address[i]].dislike - 1;
        like_list[index] = jury_panels[jury_address[i]].like - 1;
        index++;
      }
    }
    return (address_list, like_list, dislike_list);
  }

  function getAllContents() external view returns(string[] memory, string[] memory, uint256[] memory, uint256[] memory, string[] memory, string[] memory, string[] memory) {  // 청원 list 불러오기
    // 가져올 인덱스 계산하기
    string[] memory title_list = new string[](id);
    string[] memory content_list = new string[](id);
    uint256[] memory vote_list = new uint256[](id);
    uint256[] memory start_time_list = new uint256[](id);
    string[] memory reply_url_list = new string[](id);
    string[] memory category_list = new string[](id);
    string[] memory blocked_reason_list = new string[](id);


    for(uint i = 0; i < id; i++){
      title_list[i] = petitions[i].title;
      content_list[i] = petitions[i].content;
      vote_list[i] = petitions[i].vote;
      start_time_list[i] = petitions[i].start_time;
      category_list[i] = petitions[i].category;
      reply_url_list[i] = petitions[i].reply_url;
      blocked_reason_list[i] = petitions[i].blocked_reason;
    }
    return (title_list, content_list, vote_list, start_time_list, reply_url_list, category_list,blocked_reason_list);
  }

function getBlockContents(bool _is_block) external returns(Content[] memory){
    for(uint i = 0; i < id; i++){
        if (petitions[i].is_block == _is_block)
          return_indexes.push(i);
    }
    // 가져올 인덱스에 해당하는 글 array에 추가하기
    uint length = return_indexes.length;
    Content[] memory list = new Content[](length);
    for(uint i = 0; i < length; i++){
      uint _index = return_indexes[i];
      list[i].title = petitions[_index].title;
      list[i].content = petitions[_index].content;
      list[i].vote = petitions[_index].vote;
      list[i].start_time = petitions[_index].start_time;
      list[i].reply_url = petitions[_index].reply_url;
      list[i].is_replied = petitions[_index].is_replied;
      list[i].category = petitions[_index].category;
      list[i].is_block = petitions[_index].is_block;
      list[i].blocked_reason = petitions[_index].blocked_reason;
    }
    delete return_indexes;
    return list;
  }


function getPublicContents(bool _is_public) external returns(Content[] memory){
    for(uint i = 0; i < id; i++){
        if ((petitions[i].vote > criteria_vote + 1) == _is_public)
          return_indexes.push(i);
    }
    // 가져올 인덱스에 해당하는 글 array에 추가하기
    uint length = return_indexes.length;
    Content[] memory list = new Content[](length);
    for(uint i = 0; i < length; i++){
      uint _index = return_indexes[i];
      list[i].title = petitions[_index].title;
      list[i].content = petitions[_index].content;
      list[i].vote = petitions[_index].vote;
      list[i].start_time = petitions[_index].start_time;
      list[i].reply_url = petitions[_index].reply_url;
      list[i].is_replied = petitions[_index].is_replied;
      list[i].category = petitions[_index].category;
      list[i].is_block = petitions[_index].is_block;
      list[i].blocked_reason = petitions[_index].blocked_reason;
    }
    delete return_indexes;
    return list;
  }

function getRepliedContents(bool _is_replied) external returns(Content[] memory){
    for(uint i = 0; i < id; i++){
        if (petitions[i].is_replied == _is_replied)
          return_indexes.push(i);
    }
    // 가져올 인덱스에 해당하는 글 array에 추가하기
    uint length = return_indexes.length;
    Content[] memory list = new Content[](length);
    for(uint i = 0; i < length; i++){
      uint _index = return_indexes[i];
      list[i].title = petitions[_index].title;
      list[i].content = petitions[_index].content;
      list[i].vote = petitions[_index].vote;
      list[i].start_time = petitions[_index].start_time;
      list[i].reply_url = petitions[_index].reply_url;
      list[i].is_replied = petitions[_index].is_replied;
      list[i].category = petitions[_index].category;
      list[i].is_block = petitions[_index].is_block;
      list[i].blocked_reason = petitions[_index].blocked_reason;
    }
    delete return_indexes;
    return list;
  }
}