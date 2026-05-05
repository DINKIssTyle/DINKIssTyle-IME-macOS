/*
 * test_hangul.m
 * DKSTHangul 한글 오토마타 유닛 테스트
 *
 * 빌드 및 실행:
 *   clang -framework Foundation -o build/test_hangul Tests/test_hangul.m Sources/DKSTHangul.m
 *   ./build/test_hangul
 */

#import "../Sources/DKSTHangul.h"
#import <Cocoa/Cocoa.h>

static int _passed = 0;
static int _failed = 0;

#define ASSERT_STR(actual, expected, msg) do { \
  NSString *_a = (actual) ?: @"(nil)"; \
  NSString *_e = (expected); \
  if ([_a isEqualToString:_e]) { _passed++; } \
  else { _failed++; NSLog(@"FAIL: %@ — expected '%@', got '%@'", msg, _e, _a); } \
} while(0)

#define ASSERT_TRUE(cond, msg) do { \
  if ((cond)) { _passed++; } \
  else { _failed++; NSLog(@"FAIL: %@", msg); } \
} while(0)

// Helper: simulate typing a string through the engine
static void typeString(DKSTHangul *engine, NSString *keys) {
  for (NSUInteger i = 0; i < [keys length]; i++) {
    unichar c = [keys characterAtIndex:i];
    // Map character to keycode
    NSInteger keyCode = -1;
    BOOL shift = (c >= 'A' && c <= 'Z');
    unichar lower = shift ? (c - 'A' + 'a') : c;
    switch (lower) {
      case 'a': keyCode = 0;  break;  case 's': keyCode = 1;  break;
      case 'd': keyCode = 2;  break;  case 'f': keyCode = 3;  break;
      case 'h': keyCode = 4;  break;  case 'g': keyCode = 5;  break;
      case 'z': keyCode = 6;  break;  case 'x': keyCode = 7;  break;
      case 'c': keyCode = 8;  break;  case 'v': keyCode = 9;  break;
      case 'b': keyCode = 11; break;  case 'q': keyCode = 12; break;
      case 'w': keyCode = 13; break;  case 'e': keyCode = 14; break;
      case 'r': keyCode = 15; break;  case 'y': keyCode = 16; break;
      case 't': keyCode = 17; break;  case 'o': keyCode = 31; break;
      case 'u': keyCode = 32; break;  case 'i': keyCode = 34; break;
      case 'p': keyCode = 35; break;  case 'l': keyCode = 37; break;
      case 'j': keyCode = 38; break;  case 'k': keyCode = 40; break;
      case 'n': keyCode = 45; break;  case 'm': keyCode = 46; break;
      default: break;
    }
    if (keyCode < 0) continue;
    NSUInteger flags = shift ? NSEventModifierFlagShift : 0;
    [engine processCode:keyCode modifiers:flags];
  }
}

static NSString *fullResult(DKSTHangul *engine) {
  NSString *commit = [engine commitString];
  NSString *composed = [engine composedString];
  return [NSString stringWithFormat:@"%@%@", commit ?: @"", composed ?: @""];
}

// ── Test Cases ─────────────────────────────────────────────

static void testBasicSyllable(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 가 = ㄱ(r) + ㅏ(k)
  typeString(engine, @"rk");
  ASSERT_STR([engine composedString], @"가", @"Basic syllable 가");
  [engine reset];

  // 한 = ㅎ(g) + ㅏ(k) + ㄴ(s)
  typeString(engine, @"gks");
  ASSERT_STR([engine composedString], @"한", @"Basic syllable 한");
  [engine reset];

  // 글 = ㄱ(r) + ㅡ(m) + ㄹ(f)
  typeString(engine, @"rmf");
  ASSERT_STR([engine composedString], @"글", @"Basic syllable 글");
  [engine reset];

  [engine release];
}

static void testSsangJaeum(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 빠 = ㅃ(Q) + ㅏ(k)
  typeString(engine, @"Qk");
  ASSERT_STR([engine composedString], @"빠", @"Ssang 빠");
  [engine reset];

  // 까 = ㄲ(R) + ㅏ(k)
  typeString(engine, @"Rk");
  ASSERT_STR([engine composedString], @"까", @"Ssang 까");
  [engine reset];

  [engine release];
}

static void testCompoundJung(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 과 = ㄱ(r) + ㅘ(hk) = ㄱ + ㅗ + ㅏ
  typeString(engine, @"rhk");
  ASSERT_STR([engine composedString], @"과", @"Compound Jung 과");
  [engine reset];

  // 귀 = ㄱ(r) + ㅟ(nl) = ㄱ + ㅜ + ㅣ
  typeString(engine, @"rnl");
  ASSERT_STR([engine composedString], @"귀", @"Compound Jung 귀");
  [engine reset];

  // 의 = ㅇ(d) + ㅢ(ml) = ㅇ + ㅡ + ㅣ
  typeString(engine, @"dml");
  ASSERT_STR([engine composedString], @"의", @"Compound Jung 의");
  [engine reset];

  [engine release];
}

static void testCompoundJong(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 닭 = ㄷ(e) + ㅏ(k) + ㄹ(f) + ㄱ(r)
  typeString(engine, @"ekfr");
  ASSERT_STR([engine composedString], @"닭", @"Compound Jong 닭");
  [engine reset];

  // 읽 = ㅇ(d) + ㅣ(l) + ㄹ(f) + ㄱ(r)
  typeString(engine, @"dlfr");
  ASSERT_STR([engine composedString], @"읽", @"Compound Jong 읽");
  [engine reset];

  // 값 = ㄱ(r) + ㅏ(k) + ㅂ(q) + ㅅ(t)
  typeString(engine, @"rkqt");
  ASSERT_STR([engine composedString], @"값", @"Compound Jong 값");
  [engine reset];

  [engine release];
}

static void testJongToNextSyllable(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 한글 = 한(gks) + 글(rmf) → Jong ㄴ stays, ㄱ moves to next
  // Actually: ㅎ(g) ㅏ(k) ㄴ(s) ㄱ(r) ㅡ(m) ㄹ(f)
  // gk → 하, gks → 한, gksr → 한+ㄱ composing
  // Wait, ㄴ+ㄱ is not a compound jong, so ㄱ starts new syllable
  typeString(engine, @"gksrmf");
  NSString *result = fullResult(engine);
  ASSERT_STR(result, @"한글", @"Multi-syllable 한글");
  [engine reset];

  // 사람 = ㅅ(t) ㅏ(k) ㄹ(f) ㅏ(k) ㅁ(a)
  typeString(engine, @"tkfka");
  result = fullResult(engine);
  ASSERT_STR(result, @"사람", @"Multi-syllable 사람");
  [engine reset];

  [engine release];
}

static void testBackspace(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 한 → backspace → 하
  typeString(engine, @"gks");
  ASSERT_STR([engine composedString], @"한", @"Before backspace");
  [engine backspace];
  ASSERT_STR([engine composedString], @"하", @"After backspace 한→하");
  [engine backspace];
  ASSERT_STR([engine composedString], @"ㅎ", @"After backspace 하→ㅎ");
  [engine backspace];
  ASSERT_STR([engine composedString], @"", @"After backspace ㅎ→empty");
  ASSERT_TRUE(![engine backspace], @"Backspace on empty returns NO");
  [engine reset];

  [engine release];
}

static void testFullCharacterDelete(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];
  [engine setFullCharacterDelete:YES];

  // 한 → backspace → empty (full delete)
  typeString(engine, @"gks");
  [engine backspace];
  ASSERT_STR([engine composedString], @"", @"Full char delete 한→empty");
  [engine reset];

  [engine setFullCharacterDelete:NO];
  [engine release];
}

static void testCompoundJongBackspace(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];

  // 닭 → backspace → 달 (compound jong ㄺ → ㄹ)
  typeString(engine, @"ekfr");
  ASSERT_STR([engine composedString], @"닭", @"Before backspace 닭");
  [engine backspace];
  ASSERT_STR([engine composedString], @"달", @"After backspace 닭→달");
  [engine reset];

  // 닳 = ㄷ(e) + ㅏ(k) + ㄹ(f) + ㅎ(g) → compound jong ㅀ
  typeString(engine, @"ekfg");
  ASSERT_STR([engine composedString], @"닳", @"Compound jong ㅀ");
  [engine backspace];
  ASSERT_STR([engine composedString], @"달", @"After backspace 닳→달");
  [engine reset];

  [engine release];
}

static void testMoaJjiki(void) {
  DKSTHangul *engine = [[DKSTHangul alloc] init];
  [engine setMoaJjikiEnabled:YES];

  // 모아치기: ㅏ(k) + ㄱ(r) → 가 (Jung before Cho)
  typeString(engine, @"kr");
  ASSERT_STR([engine composedString], @"가", @"Moa-jjiki ㅏ+ㄱ→가");
  [engine reset];

  // 모아치기 비활성화 시
  [engine setMoaJjikiEnabled:NO];
  typeString(engine, @"kr");
  NSString *result = fullResult(engine);
  // With moa-jjiki disabled: ㅏ is flushed, ㄱ starts new
  ASSERT_STR(result, @"ㅏㄱ", @"Moa-jjiki disabled ㅏ+ㄱ→ㅏ+ㄱ");
  [engine reset];

  [engine setMoaJjikiEnabled:YES];
  [engine release];
}

// ── Main ───────────────────────────────────────────────────

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSLog(@"=== DKSTHangul Unit Tests ===");

    testBasicSyllable();
    testSsangJaeum();
    testCompoundJung();
    testCompoundJong();
    testJongToNextSyllable();
    testBackspace();
    testFullCharacterDelete();
    testCompoundJongBackspace();
    testMoaJjiki();

    NSLog(@"=== Results: %d passed, %d failed ===", _passed, _failed);
    return _failed > 0 ? 1 : 0;
  }
}
