# url_tracker_generator.py
# Run: python3 url_tracker_generator.py
# Outputs: url-tracker.html — visited vanish, Ctrl+Z undo with reverse animation + localStorage persistence
urls = [
    "https://filemoon.to/e/9pfe1u8ybgsp",
    "https://filemoon.to/e/4gdxv6l6vu69",
    "https://filemoon.to/e/kpxr6y76hybs",
    "https://filemoon.to/e/89mk5wevmmg8",
    "https://filemoon.to/e/1e780o0r6skj",
    "https://filemoon.to/e/g7bukhyf4hhv",
    "https://filemoon.to/e/tmob4ctjylyy",
    "https://filemoon.to/e/xyjn7n910fny",
    "https://filemoon.to/e/7hsw1lz84pjh",
    "https://filemoon.to/e/5fi3l2n9zxy5",
    "https://filemoon.to/e/1okl40r2ac0a",
    "https://filemoon.to/e/geyi3y0ul79a",
    "https://filemoon.to/e/gkpovh0brw2v",
    "https://filemoon.to/e/k0trppxsmgzn",
    "https://filemoon.to/e/7vc6ticrvigf",
    "https://filemoon.to/e/y4iaxvgrijka",
    "https://filemoon.to/e/y5puw6eseuti",
    "https://filemoon.to/e/p0axq06yghf9",
    "https://filemoon.to/e/gjiv0bg10p77",
    "https://filemoon.to/e/l0r5u93wckxt",
    "https://filemoon.to/e/vtxvz4yrogyv",
    "https://filemoon.to/e/w6q1scbvqku2",
    "https://filemoon.to/e/sxcbukpwwr21",
    "https://filemoon.to/e/1xzvp8db8o1x",
    "https://filemoon.to/e/o9cuajyafmrk",
    "https://filemoon.to/e/m6i0o77yuedw",
    "https://filemoon.to/e/58y4v23rb9ec",
    "https://filemoon.to/e/8sf267rrulcj",
    "https://filemoon.to/e/9r0phoa4ry0r",
    "https://filemoon.to/e/e9d4i58xyxl7",
    "https://filemoon.to/e/mqor1na8tjl4",
    "https://filemoon.to/e/k66cyypku8va",
    "https://filemoon.to/e/l35lvfujibwj",
    "https://filemoon.to/e/s4mnfkz2uifw",
    "https://filemoon.to/e/8gnpakuqlwq9",
    "https://filemoon.to/e/tciwchixok1n",
    "https://filemoon.to/e/t1jk0vrjtf53",
    "https://filemoon.to/e/k23hkhygvjrh",
    "https://filemoon.to/e/7wocvwwywj3o",
    "https://filemoon.to/e/f4qfmmnu9365",
    "https://filemoon.to/e/7f9br9myhizr",
    "https://filemoon.to/e/d5hdqrgwgp2b",
    "https://filemoon.to/e/ylaej94bq2t9",
    "https://filemoon.to/e/jke0tjwkb0ev",
    "https://filemoon.to/e/h7yznso8248o",
    "https://filemoon.to/e/mbrjkff8yhfg",
    "https://filemoon.to/e/lddgjwd6exz9",
    "https://filemoon.to/e/3vdx2hmrnmd9",
    "https://filemoon.to/e/a7ur0ogwl37x",
    "https://filemoon.to/e/f4hwgz9ohkpq",
    "https://filemoon.to/e/ax6s7uge6lru",
    "https://filemoon.to/e/nnw5cdotqzo1",
    "https://filemoon.to/e/ah1sqk8q84vt",
    "https://filemoon.to/e/ncny24n3bgfn",
    "https://filemoon.to/e/qy6b3a5wxj1d",
    "https://filemoon.to/e/gec9bnf4kmzd",
    "https://filemoon.to/e/hgd2ofuekaqo",
    "https://filemoon.to/e/gr8cyq0jno9d",
    "https://filemoon.to/e/ps41zyyh7ps1",
    "https://filemoon.to/e/mctwiit2xy3f",
    "https://filemoon.to/e/mfk88tkdntq9",
    "https://filemoon.to/e/a2rsisk1s0pl",
    "https://filemoon.to/e/zd4fvnpfupyn",
    "https://filemoon.to/e/x2fi487pypsd",
    "https://filemoon.to/e/vl6lpvtnrq4j",
    "https://filemoon.to/e/shpszdfbxpgw",
    "https://filemoon.to/e/31r843w7pax6",
    "https://filemoon.to/e/tcxh09lr2eh6",
    "https://filemoon.to/e/yutmqs7gbslb",
    "https://filemoon.to/e/6xrp0x05qe1d",
    "https://filemoon.to/e/fu15y1lkfyqv",
    "https://filemoon.to/e/meqs4oavf5dg",
    "https://filemoon.to/e/hko8qn1j14cv",
    "https://filemoon.to/e/3ds246e4ox3g",
    "https://filemoon.to/e/tc22pijif14w",
    "https://filemoon.to/e/wvepjr1kqeju",
    "https://filemoon.to/e/w4qws8jrzurm",
    "https://filemoon.to/e/ayl03zh5csba",
    "https://filemoon.to/e/q6ehb6biwhc2",
    "https://filemoon.to/e/j3nkwl2i6bzv",
    "https://filemoon.to/e/4vn0fevqlz19",
    "https://filemoon.to/e/qq4jjvla29br",
    "https://filemoon.to/e/9gw3x3jp1ys8",
    "https://filemoon.to/e/tf8gv8yc2a07",
    "https://filemoon.to/e/h454o579dqd9",
    "https://filemoon.to/e/swa8q09bpg5p",
    "https://filemoon.to/e/9o2nnjtp5b6b",
    "https://filemoon.to/e/4ccnv8t5ace9",
    "https://filemoon.to/e/lfb9l7wkvh77",
    "https://filemoon.to/e/l8ukru2uusad",
    "https://filemoon.to/e/pc5o54bu65of",
    "https://filemoon.to/e/h5ywmq2k1afd",
    "https://filemoon.to/e/43uue7k6ju1s",
    "https://filemoon.to/e/cfzamiey679s",
    "https://filemoon.to/e/hnybke4xjus7",
    "https://filemoon.to/e/ph7tk6l88dxp",
    "https://filemoon.to/e/iosxncv5mg22",
    "https://filemoon.to/e/sph81eagqyqs",
    "https://filemoon.to/e/2f5hgdvsyati",
    "https://filemoon.to/e/937jcfly2k5v",
    "https://filemoon.to/e/ps8w0r7nt0vv",
    "https://filemoon.to/e/egqfnx0vu7i2",
    "https://filemoon.to/e/bls4bryem3v2",
    "https://filemoon.to/e/9gevxwvkik56",
    "https://filemoon.to/e/txoblszqcbwk",
    "https://filemoon.to/e/5jt2z98gkj6x",
    "https://filemoon.to/e/tjz78hczlolx",
    "https://filemoon.to/e/otl7d5asztnr",
    "https://filemoon.to/e/hsszgdiaazg1",
    "https://filemoon.to/e/c3fnm1mxyiak",
    "https://filemoon.to/e/f3ojxksbig8w",
    "https://filemoon.to/e/wdx9c05aye0r",
    "https://filemoon.to/e/xqyxija4st0h",
    "https://filemoon.to/e/bcfd8wia0jlt",
    "https://filemoon.to/e/58v5wopkbx2t",
    "https://filemoon.to/e/624l63h6d0w0",
    "https://filemoon.to/e/j6ie9zukv2lw",
    "https://filemoon.to/e/hfvwrftdrrrm",
    "https://filemoon.to/e/8iej1isnfckl",
    "https://filemoon.to/e/7jydtag7xfnm",
    "https://filemoon.to/e/qhu76293pe8f",
    "https://filemoon.to/e/t9zr99gshg0o",
    "https://filemoon.to/e/b0hm7hysiyqi",
    "https://filemoon.to/e/ed781mgmv3lf",
    "https://filemoon.to/e/yznu46935oou",
    "https://filemoon.to/e/1fbu4rrbenrb",
    "https://filemoon.to/e/qwmuxw7jednl",
    "https://filemoon.to/e/yjlq4m22rdws",
    "https://filemoon.to/e/htu25eh68n2z",
    "https://filemoon.to/e/jtfobeb883aa",
    "https://filemoon.to/e/307j0fb4thz4",
    "https://filemoon.to/e/4wnkn7dp7ncs",
    "https://filemoon.to/e/yikxrtkwh1sg",
    "https://filemoon.to/e/9jrg7olo4lv8",
    "https://filemoon.to/e/zy2yx0sc5u1b",
    "https://filemoon.to/e/i67rlef52a3g",
    "https://filemoon.to/e/t095vuqurpv7",
    "https://filemoon.to/e/gxnp5zc97vix",
    "https://filemoon.to/e/9x03ntchwd6v",
    "https://filemoon.to/e/946uhjk25s7e",
    "https://filemoon.to/e/3tigoa6vxxhm",
    "https://filemoon.to/e/pdkriwn1je5m",
    "https://filemoon.to/e/ue654w2kcddy",
    "https://filemoon.to/e/mptmemzqqha3",
    "https://filemoon.to/e/zgriwd03u9xh",
    "https://filemoon.to/e/qyhu88jjpine",
    "https://filemoon.to/e/pbgjpbtdjag8",
    "https://filemoon.to/e/gmdijpahctrl",
    "https://filemoon.to/e/zhdwvo3prnvn",
    "https://filemoon.to/e/6zzd30wr20qd",
    "https://filemoon.to/e/j1h8la6zkord",
    "https://filemoon.to/e/l16jxfm01l9v",
    "https://filemoon.to/e/5i25n33n4h5k",
    "https://filemoon.to/e/hnmvuwvz545q",
    "https://filemoon.to/e/w7ddcu2mlcck",
    "https://filemoon.to/e/uhucyt7klfm5",
    "https://filemoon.to/e/2q38gzkbo8ed",
    "https://filemoon.to/e/cuue9a8hu74k",
    "https://filemoon.to/e/q12nutyjm52j",
    "https://filemoon.to/e/g939v7f2xlxb",
    "https://filemoon.to/e/1mstdg4p8fw4",
    "https://filemoon.to/e/62ssfzionow0",
    "https://filemoon.to/e/j8w6uebye51z",
    "https://filemoon.to/e/vc5cs0cc00q6",
    "https://filemoon.to/e/184xwug18m6a",
    "https://filemoon.to/e/0smr25r7lfdx",
    "https://filemoon.to/e/c8azs4nnvbjl",
    "https://filemoon.to/e/xjd1eoe0sodt",
    "https://filemoon.to/e/m5ptrk0ovu6y",
    "https://filemoon.to/e/up3mbs52yime",
    "https://filemoon.to/e/uu5kd00uajw4",
    "https://filemoon.to/e/2e3ba1rzg5s8",
    "https://filemoon.to/e/qiljlnzj0c48",
    "https://filemoon.to/e/oqof91yi7nd1",
    "https://filemoon.to/e/0covfkc9a740",
    "https://filemoon.to/e/73qzs4incwf1",
    "https://filemoon.to/e/gpx7iyxvvxlq",
    "https://filemoon.to/e/fbxwoxp1db9x",
    "https://filemoon.to/e/ffnu7irdvbxz",
    "https://filemoon.to/e/as3r2khz7857",
    "https://filemoon.to/e/cmvpmu96ehf5",
    "https://filemoon.to/e/ozx3ohq035wt",
    "https://filemoon.to/e/bw7bbi74j5tz",
    "https://filemoon.to/e/zccsn08dbs73",
    "https://filemoon.to/e/vgxlujcgnjw3",
    "https://filemoon.to/e/yuvpb7cz6sox",
    "https://filemoon.to/e/1peo2m199ycw",
    "https://filemoon.to/e/pfkmrynem2ml",
    "https://filemoon.to/e/4x6fpupkrr9d",
    "https://filemoon.to/e/6tpvadqbk7e1",
    "https://filemoon.to/e/gcylpidmqhqg",
    "https://filemoon.to/e/y9a4hb0tss7z",
    "https://filemoon.to/e/eqk892h8g64k",
    "https://filemoon.to/e/owhs4ga2cn6r",
    "https://filemoon.to/e/2ici8nxjlcxl",
    "https://filemoon.to/e/0civ2norcd6e",
    "https://filemoon.to/e/ar9qq4v7d2vc",
    "https://filemoon.to/e/e8qx8y3deesx",
    "https://filemoon.to/e/i9fndjvtwluy",
    "https://filemoon.to/e/fk3za76ceb4z",
    "https://filemoon.to/e/h3wt1vhqou46",
    "https://filemoon.to/e/ynotz7fo2ajv",
    "https://filemoon.to/e/0npur6idftol",
    "https://filemoon.to/e/ooy5y33xgwk1",
    "https://filemoon.to/e/v0wikudyp2va",
    "https://filemoon.to/e/gq7jffar5pk9",
    "https://filemoon.to/e/sjcn9510snka",
    "https://filemoon.to/e/nhja2hpufy21",
    "https://filemoon.to/e/na7pidu02522",
    "https://filemoon.to/e/7246j738sw5t",
    "https://filemoon.to/e/4u8ilngicees",
    "https://filemoon.to/e/ohccgb4ralaa",
    "https://filemoon.to/e/kbpuwcpg8nua",
    "https://filemoon.to/e/ypafjpwldxgz",
    "https://filemoon.to/e/tui7o1pe9r2b",
    "https://filemoon.to/e/d9gshb1o62kq",
    "https://filemoon.to/e/ffa5wxnprquw",
    "https://filemoon.to/e/ji7s8tyhugi7",
    "https://filemoon.to/e/m7th8u6evbtp",
    "https://filemoon.to/e/ricmz8cbojr6",
    "https://filemoon.to/e/lrapr1d28t7b",
    "https://filemoon.to/e/alf4c9z0bzyw",
    "https://filemoon.to/e/cvdtha8zbeos",
    "https://filemoon.to/e/ta896al3tnb2",
    "https://filemoon.to/e/ovubtmz2ug8a",
    "https://filemoon.to/e/xo89f1ytrmlo",
    "https://filemoon.to/e/dn7epapt7hvp",
    "https://filemoon.to/e/yjdy1xgvt9pp",
    "https://filemoon.to/e/c3rw97qrlv8z",
    "https://filemoon.to/e/asn3b2c4qbnv",
    "https://filemoon.to/e/ggb14104rmo0",
    "https://filemoon.to/e/k1mreihr3ip2",
    "https://filemoon.to/e/5qghn3l8jw46",
    "https://filemoon.to/e/fiqo0ayjikx2",
    "https://filemoon.to/e/dk1j968mgx5j",
    "https://filemoon.to/e/z68l72n4dgpk",
    "https://filemoon.to/e/653163zv0ol4",
    "https://filemoon.to/e/5z3cotpqzw84",
    "https://filemoon.to/e/befvkd38bvjk",
    "https://filemoon.to/e/14zhsijghpg0",
    "https://filemoon.to/e/alqh331cwf97",
    "https://filemoon.to/e/t584llsyg5x3",
    "https://filemoon.to/e/kdnbpvoyfy7l",
    "https://filemoon.to/e/7j79qrwyp7n1",
    "https://filemoon.to/e/loyte4ncth3z",
    "https://filemoon.to/e/b9qa7dexo169",
    "https://filemoon.to/e/vuxjr2nbxwap",
    "https://filemoon.to/e/mzojwjo7tu4y",
    "https://filemoon.to/e/znex0gkhod3g",
    "https://filemoon.to/e/98g3yfvt7x6b",
    "https://filemoon.to/e/jsy0zrzdi896",
    "https://filemoon.to/e/ghqwg03hxwce",
    "https://filemoon.to/e/0dtll518th7g",
    "https://filemoon.to/e/jpsyf9j5s14i"
]

html_template = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>URL Ψ TRACKER</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto+Mono:wght@500&family=Cinzel+Decorative:wght@700&display=swap">
    <style>
        :root {{
            --bg-dark: #0A131A;
            --accent-cyan: #15fafa;
            --text-primary: #e0ffff;
        }}
        body {{ background: var(--bg-dark); color: var(--text-primary); font-family: 'Roboto Mono', monospace; padding: 40px; text-align: center; }}
        h1 {{ font-family: 'Cinzel Decorative', serif; font-size: 2.5rem; background: linear-gradient(to right, #15fafa, #15adad); -webkit-background-clip: text; background-clip: text; color: transparent; margin-bottom: 20px; }}
        .glyph {{ width: 120px; height: 120px; margin: 20px auto; filter: drop-shadow(0 0 20px var(--accent-cyan)); animation: pulse 4s infinite; }}
        @keyframes pulse {{ 0%,100% {{ filter: drop-shadow(0 0 20px var(--accent-cyan)); }} 50% {{ filter: drop-shadow(0 0 30px var(--accent-cyan)); }} }}
        ul {{ list-style: none; padding: 0; max-width: 600px; margin: 0 auto; }}
        li {{ 
            margin: 12px 0; 
            overflow: hidden;
            max-height: 80px;
            transition: max-height 0.8s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.8s ease, margin 0.8s ease;
        }}
        li.vanished {{ 
            max-height: 0; 
            opacity: 0;
            margin: 0;
        }}
        a {{ 
            display: block; 
            padding: 14px 20px; 
            background: rgba(10,15,26,0.7); 
            border: 1px solid transparent; 
            border-radius: 10px; 
            color: #15fafa; 
            text-decoration: none; 
            font-size: 14px; 
            transition: all 0.4s ease; 
            box-shadow: 0 0 12px rgba(21,250,250,0.2);
        }}
        a:hover {{ 
            background: rgba(21,250,250,0.2); 
            box-shadow: 0 0 25px rgba(21,250,250,0.6); 
            transform: translateY(-3px); 
        }}
        a:visited {{ animation: dematerialize 1s forwards; }}
        @keyframes dematerialize {{
            0% {{ opacity: 1; transform: scale(1); filter: blur(0); }}
            60% {{ opacity: 0.4; transform: scale(1.08); filter: blur(3px); }}
            100% {{ opacity: 0; transform: scale(0.9); filter: blur(10px); }}
        }}
        @keyframes rematerialize {{
            0% {{ opacity: 0; transform: scale(0.9); filter: blur(10px); max-height: 0; }}
            60% {{ opacity: 0.4; transform: scale(1.08); filter: blur(3px); }}
            100% {{ opacity: 1; transform: scale(1); filter: blur(0); max-height: 80px; }}
        }}
        li.rematerializing {{ animation: rematerialize 1s forwards; }}
        .info {{ margin-top: 40px; font-size: 14px; opacity: 0.8; }}
        .counter {{ margin: 20px 0; font-size: 18px; }}
        .undo-hint {{ margin-top: 10px; font-size: 12px; opacity: 0.6; }}
    </style>
    <script>
        const totalCount = {count};
        let visibleCount = totalCount;
        let undoStack = JSON.parse(localStorage.getItem('gofileUndoStack') || '[]');

        function saveUndoStack() {{
            localStorage.setItem('gofileUndoStack', JSON.stringify(undoStack));
        }}

        document.addEventListener('DOMContentLoaded', () => {{
            const ul = document.querySelector('ul');
            const lis = ul.querySelectorAll('li');

            lis.forEach(li => {{
                const a = li.querySelector('a');
                if (a.matches(':visited')) {{
                    li.classList.add('vanished');
                    visibleCount--;
                }}
            }});
            updateCounter();

            lis.forEach(li => {{
                const a = li.querySelector('a');
                a.addEventListener('click', e => {{
                    setTimeout(() => {{
                        if (!li.classList.contains('vanished')) {{
                            const liClone = li.cloneNode(true);
                            undoStack.push({{html: li.outerHTML, url: a.href}});
                            saveUndoStack();
                            li.classList.add('vanished');
                            visibleCount--;
                            updateCounter();
                        }}
                    }}, 300);
                }});
            }});
        }});

        function updateCounter() {{
            document.querySelector('.counter').textContent = `Remaining: ${{visibleCount}} / ${{totalCount}}`;
        }}

        // Ctrl+Z Undo with reverse animation
        document.addEventListener('keydown', e => {{
            if ((e.ctrlKey || e.metaKey) && e.key === 'z' && undoStack.length > 0) {{
                e.preventDefault();
                const last = undoStack.pop();
                saveUndoStack();

                const ul = document.querySelector('ul');
                const tempDiv = document.createElement('div');
                tempDiv.innerHTML = last.html;
                const restoredLi = tempDiv.firstChild;

                const existing = [...ul.children].find(li => li.querySelector('a').href === last.url);
                if (existing) {{
                    ul.replaceChild(restoredLi, existing);
                }} else {{
                    ul.appendChild(restoredLi);
                }}

                restoredLi.classList.add('rematerializing');
                visibleCount++;
                updateCounter();

                restoredLi.addEventListener('animationend', () => {{
                    restoredLi.classList.remove('rematerializing');
                }}, {{once: true}});
            }}
        }});
    </script>
</head>
<body>
    <svg class="glyph" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
      <path d="M 64,12 A 52,52 0 1 1 63.9,12 Z" stroke="#15fafa" stroke-dasharray="21.78 21.78" stroke-width="2" opacity="0.8"/>
      <path d="M 64,20 A 44,44 0 1 1 63.9,20 Z" stroke="#15fafa" stroke-dasharray="10 10" stroke-width="1.5" opacity="0.5"/>
      <path d="M64 30 L91.3 47 L91.3 81 L64 98 L36.7 81 L36.7 47 Z" stroke="#15fafa" fill="none" stroke-width="3"/>
      <text x="64" y="74" text-anchor="middle" dominant-baseline="middle" fill="#15fafa" font-size="56" font-weight="700" font-family="'Cinzel Decorative', serif">
        Ψ
      </text>
    </svg>

    <h1>URL Ψ TRACKER — {count} LINKS</h1>
    <div class="counter">Remaining: {count} / {count}</div>

    <ul>
{links}    </ul>

    <div class="info">
        Click → open + dematerialize<br>
        Ctrl+Z → undo (reverse animation)<br>
        <span class="undo-hint">Undo stack persists across sessions</span>
    </div>
</body>
</html>"""

links_html = ""
for url in urls:
    short = url.replace("https://gofile.io/d/", "").replace("http://gofile.io/d/", "")
    links_html += f'        <li><a href="{url}" target="_blank">{short}</a></li>\n'

total_count = len(urls)
output = html_template.format(count=total_count, links=links_html)

with open("url-tracker.html", "w", encoding="utf-8") as f:
    f.write(output)

print(f"Resurrection complete: url-tracker.html generated with {len(urls)} links.")
print("Click → dematerialize")
print("Ctrl+Z → rematerialize with reverse animation")
print("Undo stack persists via localStorage — eternal across sessions")
