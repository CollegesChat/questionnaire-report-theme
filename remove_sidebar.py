import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# 正则匹配 aside 标签及其内容
ASIDE_RE = re.compile(r'<aside.*?>.*?</aside>', flags=re.DOTALL)
NAME_RE = re.compile(
    r'property=\"og:title\" content=\"([\u4e00-\u9fa5\s\(\)]+)\"'
)  # 提取文件名（不含扩展名）


def process_html_file(file_path):
    """处理单个文件并返回清理的字节数"""
    try:
        # 读取并计算原始字节
        content = file_path.read_text(encoding='utf-8')
        original_byte_size = len(content.encode('utf-8'))
        # 执行清理并计算新字节
        new_content = ASIDE_RE.sub('', content)
        new_byte_size = len(new_content.encode('utf-8'))

        cleaned_bytes = original_byte_size - new_byte_size

        # 写回文件
        file_path.write_text(new_content, encoding='utf-8')

        # 输出文件名
        print(f'处理中: {re.search(NAME_RE, content).group(1)}')

        return cleaned_bytes
    except Exception as e:
        print(f'❌ 出错 {file_path.name}: {e}')
        return 0


def clean_sidebar(paths_list):
    all_html_files = []

    # 1. 扫描所有路径
    for p in paths_list:
        path_obj = Path(p)
        if path_obj.exists():
            # 查找该目录下所有 html
            found = list(path_obj.rglob('*.html'))
            all_html_files.extend(found)
            print(f'在目录 [{p}] 中找到 {len(found)} 个文件')
        else:
            print(f'⚠️ 路径不存在: {p}')

    if not all_html_files:
        print('未发现任何 HTML 文件，程序退出。')
        return

    print(f'\n🚀 开始多线程处理共 {len(all_html_files)} 个文件...\n' + '-' * 40)

    # 2. 多线程执行
    with ThreadPoolExecutor() as executor:
        # 收集所有文件的清理量（Bytes）
        results = list(executor.map(process_html_file, all_html_files))

    # 3. 汇总统计
    total_bytes = sum(results)
    total_mb = total_bytes / (1024 * 1024)

    print('\n' + '=' * 40)
    print('✅ 任务完成报告')
    print(f'📂 总处理目录数: {len(paths_list)}')
    print(f'📄 总处理文件数: {len(all_html_files)}')
    print(f'🧹 累计清理数据: {total_mb:.2f} MB')
    print('=' * 40)


my_paths = [r'public\archived', r'public\universities']

clean_sidebar(my_paths)
