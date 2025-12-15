#import <Foundation/Foundation.h>

@interface DKSTHangul : NSObject

// 현재 조합 중인 글자 (Preedit String)
@property (nonatomic, readonly) NSString *composedString;
// 조합이 완료되어 확정된 글자 (Commit String)
@property (nonatomic, readonly) NSString *commitString;

- (void)reset;
// 백스페이스 처리. 처리했으면 YES (조합 상태 변경), 아니면 NO (지울 글자 없음).
- (BOOL)backspace;
// 키 입력을 처리. 처리했으면 YES, 아니면 NO 반환.
- (BOOL)processCode:(NSInteger)keyCode modifiers:(NSUInteger)flags;

@end
