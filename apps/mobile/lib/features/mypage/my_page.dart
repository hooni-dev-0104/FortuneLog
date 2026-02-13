import 'package:flutter/material.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Card(child: ListTile(title: Text('계정 정보'), subtitle: Text('이메일, 로그아웃'))),
          Card(child: ListTile(title: Text('출생정보 관리'), subtitle: Text('프로필 조회/수정'))),
          Card(child: ListTile(title: Text('주문/결제'), subtitle: Text('결제 상태 확인'))),
          Card(child: ListTile(title: Text('구독 관리'), subtitle: Text('active/grace/expired/canceled'))),
          Card(child: ListTile(title: Text('약관/개인정보 처리방침'), subtitle: Text('정책 문서 확인'))),
        ],
      ),
    );
  }
}
