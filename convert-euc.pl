#!/usr/bin/perl -w

# Comments are in EUC Kanji code.

# これはhyperref.styとpLaTeX2eにより生成された日本語のPDF bookmark
# を含むPostScriptの必要な部分をUnicodeに変換するスクリプトです。
# 標準入力からの入力を変換して標準出力に書き出します

# PostScriptの中の/Title (文字列)と/Author (文字列)の「(文字列)」の部分を
# 変換します。「文字列」はEUC漢字コードになっていないとうまく動作しません。

# 最新版は http://www.rmatsumoto.org/tex-ps-pdf/hyperref.ja.html
# から入手できます。バグレポートは以下のメールアドレスにお願いします。
# 松本 隆太郎

# 変更: 2007年1月4日
# 黒木裕介氏 (http://www.misojiro.t.u-tokyo.ac.jp/~kuroky/) 
# から/Subject, /Keywordにある日本語も変換するパッチを頂き適用した

# 変更: 2006年6月7日
# 土村 展之氏 (http://www.nn.iij4u.or.jp/~tutimura/)からperl 5.6で
# 使った時に警告が出なくなるパッチを頂いたのでそれを当てた。ロジックに
# は変更なし。
# 同じく土村氏から、Perl 5.8で導入されたEncodeモジュールをJcodeの
# 代わりに使うパッチを頂いたので当てた。また、そのパッチで第一引数で
# EUCとシフトJISを切替えられるようになった。

# プログラムの説明
#
# /Title または /Author という文字列が有ったら、そのあとに続く (と) で括
# られた文字列の始めと終りを $start_of_string と $end_of_string にセット
# する。そのあと文字列を substr で切り出して \ の意味をPostScriptの規格
# で定められたように解釈し、Unicodeに変換して、16進数表現に変換する。
# 16進数表現にしないとAcrobat Distillerでエラーが生じることが有った。

use strict;
use Encode;

my $sjis = 0;  # EUC
#my $sjis = 1;  # SJIS

# SJIS 漢字の1バイトめかどうか
sub iskanji1 {
    my ($char) = @_;
    my $c = ord($char);
    return (($c>=0x81 && $c<=0x9f) || ($c>=0xe0 && $c<=0xfc));
}

# )で括られた文字列の終わりを探す
sub find_end {
  my ($line, $start) = @_;
  my ($i, $open_paren, $char);

  $open_paren = 0; # 開いている括弧の数
  for ($i = $start; $i < length($line); ++$i) {
    $char = substr($line, $i, 1);
    if ($sjis && iskanji1($char)) {
      # SJIS漢字なら2バイト進む
      ++$i;
    } elsif ($char eq "\\") {
      # \( などは無視
      ++$i;
    } elsif ($char eq "(") {
      ++$open_paren;
    } elsif ($char eq ")") {
      if (-1 == --$open_paren) {
        return $i - 1;
      }
    }
  }
  return (-1);
}

sub convert_string {
  my ($str) = @_;
  my ($i, $newstr, $hexstr);

  # \ を解釈する.
  $newstr = "";
  for ($i=0; $i < length($str); ++$i) {
    if ($sjis && iskanji1(substr($str, $i, 1))) {
      $newstr .= substr($str, $i, 2);
      ++$i; next; # SJIS漢字なら2バイト進む
    }
    if (substr($str, $i, 1) ne "\\") {
      $newstr .= substr($str, $i, 1);
      next;
    }
    if (substr($str, $i+1, 1) =~ /[0-3]/) {
      # 3桁の8進数
      $newstr .= sprintf('%c', oct(substr($str, $i+1, 3)));
      $i += 3;
      next;
    }

    # \ のすぐ後に CRまたはLFまたはCRLFが続いた場合無視する
    if (substr($str, $i+1, 2) eq "\r\n") {
      $i += 2;
      next;
    } elsif (substr($str, $i+1, 1) eq "\n" || substr($str, $i+1, 1) eq "\r") {
      ++$i;
      next
    }

    # \n, \r, \t, \f, \b の解釈はperlにやらせる
    if (substr($str, $i+1, 1) =~ /[nrtbf]/) {
      $newstr .= eval('"' . substr($str, $i, 2) . '"');
      ++$i;
      next;
    }

    # それ以外のものは \ の後の文字をそのまま持ってくる.
    $newstr .= substr($str, $i+1, 1);
    $i++;
  }
#  print (STDERR  $newstr . "\n");

  # Unicode に変換
  if ($sjis) { Encode::from_to($newstr, "shiftjis", "UCS-2"); }
  else       { Encode::from_to($newstr, "euc-jp",   "UCS-2"); }

  # 16進数に直す
  $hexstr = '';
  for ($i=0; $i < length($newstr); ++$i) {
    $hexstr .= sprintf("%02X", ord(substr($newstr, $i, 1)));
  }

  # <と>はPostScriptで文字列が16進表現されていることを示す
  # FEFFは文字列がUnicodeであることを示す
  return "<FEFF" . $hexstr . ">";
}

# $pattern 直後の位置を返す
sub my_index {
  my ($str, $pattern) = @_;

  my $i = index($str, $pattern, 0);
  if ($i >= 0) { $i += length($pattern); }
  else         { $i = length($str) + 1; }  # $pattern なし
  return $i;
}

# 1行処理する関数
sub process_1line {
  my ($line) = @_;
  my ($tmp, $start_of_string, $end_of_string, $start);

  $start = my_index($line, '/Author');
  $tmp = my_index($line, '/Title');    if ($start > $tmp) { $start = $tmp; }
  $tmp = my_index($line, '/Subject');  if ($start > $tmp) { $start = $tmp; }
  $tmp = my_index($line, '/Keywords'); if ($start > $tmp) { $start = $tmp; }

  if ($start > length($line)) { # /Author などがない
    print $line;
    return;
  }

  while (($start_of_string = index($line, '(', $start)) == -1) {
    $tmp = <STDIN>;
    $line = $line . $tmp;
  }
  ++$start_of_string; # (の次を文字列のはじめにする

  while (($end_of_string = &find_end($line, $start_of_string)) == -1) {
    $tmp = <STDIN>;
    $line = $line . $tmp;
  }

  print substr($line, 0, $start_of_string-1) . # 括弧の手前まで出力
        &convert_string(substr($line, $start_of_string,
          $end_of_string-$start_of_string+1));

  # 残りの部分を処理
  &process_1line(substr($line, $end_of_string+2,
                 length($line)-($end_of_string+2)));
}

if (scalar(@ARGV) > 1) {
  print STDERR "Usage: $0 [euc|sjis] <input-file >output-file\n";
  exit 1;
}

if (scalar(@ARGV) == 1) {
  if ($ARGV[0] =~ /^euc$/i) {
    $sjis = 0;
  } elsif ($ARGV[0] =~ /^sjis$/i) {
    $sjis = 1;
  } else {
    print STDERR "$0: Unknown option '$ARGV[0]'\n";
    exit 1;
  }
}
while (<STDIN>) { &process_1line($_); }
exit 0;
