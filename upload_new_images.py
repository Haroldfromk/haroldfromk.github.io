import os
import re
import subprocess
import boto3
from pathlib import Path
from botocore.config import Config

# R2 설정
ACCOUNT_ID = "a417455c35c5f9905bb492397e2edda7"
ACCESS_KEY_ID = os.environ.get("R2_KEY_ID")
SECRET_ACCESS_KEY = os.environ.get("R2_SECRET")
BUCKET_NAME = "blog-images"
PUBLIC_URL = "https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev"

BLOG_DIR = "/Users/dongik/Documents/Workspace/blog"
UPLOAD_DIR = f"{BLOG_DIR}/assets/images/upload"
POSTS_DIR = f"{BLOG_DIR}/_posts"

def compress_images(upload_files):
    """png 파일 pngquant로 압축"""
    png_files = [f for f in upload_files if f.suffix.lower() == '.png']
    if not png_files:
        print("⏭️  압축할 PNG 없음")
        return

    print(f"\n=== PNG 압축 ({len(png_files)}개) ===")
    for f in png_files:
        before = f.stat().st_size
        result = subprocess.run(
            ['pngquant', '--force', '--quality=65-85', '--ext', '.png', str(f)],
            capture_output=True
        )
        if result.returncode == 0:
            after = f.stat().st_size
            saved = (before - after) / 1024
            print(f"  ✅ {f.name}: {before//1024}KB → {after//1024}KB (절약 {saved:.0f}KB)")
        else:
            print(f"  ⏭️  스킵: {f.name} (PNG 아님 또는 압축 불가)")

def get_r2_client():
    return boto3.client(
        "s3",
        endpoint_url=f"https://{ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=ACCESS_KEY_ID,
        aws_secret_access_key=SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )

def sanitize_folder(name):
    name = name.replace('(', '').replace(')', '')
    name = name.replace(' ', '-')
    while '--' in name:
        name = name.replace('--', '-')
    return name.strip('-')

def get_content_type(ext):
    ext = ext.lower()
    types = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".gif": "image/gif",
        ".webp": "image/webp",
        ".svg": "image/svg+xml",
    }
    return types.get(ext, "application/octet-stream")

def upload_to_r2(client, local_path, r2_key):
    try:
        client.head_object(Bucket=BUCKET_NAME, Key=r2_key)
        print(f"  ⏭️  스킵 (이미 존재): {r2_key}")
        return True
    except:
        pass

    try:
        content_type = get_content_type(local_path.suffix)
        client.upload_file(
            str(local_path),
            BUCKET_NAME,
            r2_key,
            ExtraArgs={"ContentType": content_type}
        )
        print(f"  ✅ R2 업로드: {r2_key}")
        return True
    except Exception as e:
        print(f"  ❌ 업로드 실패: {e}")
        return False

def find_md_file_with_upload_refs():
    """upload 폴더 이미지를 참조하는 md 파일 찾기"""
    upload_path = Path(UPLOAD_DIR)
    upload_files = list(upload_path.iterdir()) if upload_path.exists() else []
    upload_files = [f for f in upload_files if f.is_file() and not f.name.startswith('.')]

    if not upload_files:
        print("⚠️  upload 폴더가 비어있어.")
        return []

    print(f"📁 upload 폴더에 {len(upload_files)}개 파일:")
    for f in upload_files:
        print(f"  - {f.name}")

    # md 파일에서 /assets/images/upload/ 참조 찾기
    results = []
    for md_path in Path(POSTS_DIR).rglob("*.md"):
        content = md_path.read_text(encoding='utf-8')
        if '/assets/images/upload/' in content:
            results.append(md_path)

    return results, upload_files

def process(md_path, upload_files, client):
    """
    성공적으로 R2 업로드 + md 치환된 파일명(set)을 반환.
    실패했거나 애초에 이 md에서 참조되지 않은 파일은 포함하지 않음.
    """
    content = md_path.read_text(encoding='utf-8')
    original = content
    succeeded = set()

    folder_name = sanitize_folder(md_path.stem)
    print(f"\n📄 {md_path.name}")
    print(f"  → R2 폴더: {folder_name}/")

    for upload_file in upload_files:
        filename = upload_file.name
        local_ref = f"/assets/images/upload/{filename}"

        if local_ref not in content:
            continue

        r2_key = f"{folder_name}/{filename}"
        r2_url = f"{PUBLIC_URL}/{r2_key}"

        if upload_to_r2(client, upload_file, r2_key):
            content = content.replace(local_ref, r2_url)
            print(f"  🔗 교체: {local_ref} → {r2_url}")
            succeeded.add(filename)
        else:
            print(f"  ⚠️  업로드 실패로 upload 폴더에 유지: {filename}")

    if content != original:
        md_path.write_text(content, encoding='utf-8')
        print(f"  💾 md 저장 완료")
    else:
        print(f"  ℹ️  변경사항 없음")

    return succeeded

def clear_upload_folder(upload_files, succeeded_filenames):
    """
    성공적으로 업로드 + 치환된 파일만 upload 폴더에서 삭제.
    실패했거나 어떤 md에서도 참조되지 않은 파일은 그대로 남김.
    """
    kept = []
    for f in upload_files:
        if f.name in succeeded_filenames:
            f.unlink()
            print(f"  🗑️  삭제: {f.name}")
        else:
            kept.append(f.name)

    if kept:
        print(f"  📌 유지됨 (업로드 안 됨 또는 참조 없음): {', '.join(kept)}")
    print("✅ upload 폴더 정리 완료")

def main():
    if not ACCESS_KEY_ID or not SECRET_ACCESS_KEY:
        print("❌ 환경변수 필요:")
        print("export R2_KEY_ID='your_access_key_id'")
        print("export R2_SECRET='your_secret_key'")
        exit(1)

    result = find_md_file_with_upload_refs()
    if not result:
        return

    md_files, upload_files = result

    if not md_files:
        print("\n⚠️  /assets/images/upload/ 를 참조하는 md 파일이 없어.")
        print("md 파일에 이미지 경로를 /assets/images/upload/파일명 으로 작성해줘.")
        return

    client = get_r2_client()

    print("\n=== 이미지 압축 ===")
    compress_images(upload_files)

    all_succeeded = set()
    for md_path in md_files:
        succeeded = process(md_path, upload_files, client)
        all_succeeded |= succeeded

    print("\n=== upload 폴더 정리 ===")
    clear_upload_folder(upload_files, all_succeeded)

    print("\n🎉 완료! 이제 git add & push 하면 돼.")

if __name__ == "__main__":
    main()
