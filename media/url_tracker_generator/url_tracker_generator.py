# url_tracker_generator.py
# Run: python3 url_tracker_generator.py
# Outputs: url-tracker.html — visited vanish, Ctrl+Z undo with reverse animation + localStorage persistence
urls = [
    "https://filemoon.to/e/4r24mkjs3rth/Leggy",
    "https://filemoon.to/e/kal7weylc1ab/Leggy2",
    "https://filemoon.to/e/a1z3yluiqpyd/leggyleather",
    "https://filemoon.to/e/vpesl84q4tuq/LegsTrain1",
    "https://filemoon.to/e/pt6vjk6z350a/LegsTrain2",
    "https://filemoon.to/e/8mngpq65b4i7/LegsTrain3",
    "https://filemoon.to/e/epmm5n94pz0e/Lesteenthighs",
    "https://filemoon.to/e/0mawirodpvfl/LG_XRAY_FHD_049",
    "https://filemoon.to/e/w2h6gq2gqjm2/LG_XRAY_FHD_050",
    "https://filemoon.to/e/n8fec9bo199v/like_pikachu_cheeks",
    "https://filemoon.to/e/fc27r2ld2a9w/Love_that_bend_over_-1080p60H",
    "https://filemoon.to/e/pfsl8ayvljt2/lq001",
    "https://filemoon.to/e/fql7axga12hn/lv_0_20230908124220",
    "https://filemoon.to/e/1k8ppvwdi98g/Mamacita",
    "https://filemoon.to/e/47aco6fe8iad/Meaty_ass_in_yoga_pants_-1080p60H",
    "https://filemoon.to/e/ly3mvnbiwxjd/Mekaze-Jenas-Lover2222",
    "https://filemoon.to/e/c12wnqmft9fv/metro_grey_shorts_wtrm",
    "https://filemoon.to/e/ewl135w12vkw/Milf_in_flared_yoga_pants_-1080p60H",
    "https://filemoon.to/e/ymwm92dfgqeg/Milf_in_Grey_Edit",
    "https://filemoon.to/e/h9jlqee2h9qi/MJ482_Cleavage_and_involuntary_Uppy",
    "https://filemoon.to/e/eb68cnbz6fh6/MJ483_Pokies_in_yellow_Top",
    "https://filemoon.to/e/3u14sllny44m/mss_perfect_blonde_teen_body_in_black_n_yellow",
    "https://filemoon.to/e/sxagjyslrw9m/My_friend_s_ass_-_Part_6",
    "https://filemoon.to/e/aak5hd8bxk7t/My_Movie__1_",
    "https://filemoon.to/e/imbo8ozw91m6/My_Movie_005_09_2023",
    "https://filemoon.to/e/2s3xpm4daoa4/My_Movie_01233456",
    "https://filemoon.to/e/z8jrfa7p4y56/My_Movie_04_09_2023",
    "https://filemoon.to/e/8zxw23jvjamb/My_Movie_05_09_2023",
    "https://filemoon.to/e/vkwbc13nohwm/My_Movie_07_09_2023",
    "https://filemoon.to/e/auqy91zioylr/My_Movie_10_09_2023",
    "https://filemoon.to/e/cjojn6tewcl3/My_Movie_123456789",
    "https://filemoon.to/e/7lcyxpouv1h2/My_Movie_2",
    "https://filemoon.to/e/87vx7myi2y69/My_Movie_22",
    "https://filemoon.to/e/hlmtonq8w528/My_Movie_3",
    "https://filemoon.to/e/wp1dh8o2qllw/My_Movie_5",
    "https://filemoon.to/e/5q9yka29m5yg/My_Movie_6",
    "https://filemoon.to/e/jsvvdn65p049/My_Movie_8",
    "https://filemoon.to/e/naqx2hbji1cb/My_Movie-1080p60H",
    "https://filemoon.to/e/be4ped66nn7j/My_Movie",
    "https://filemoon.to/e/kq0vh6uurp71/My",
    "https://filemoon.to/e/bze7v0ixnkx9/Nice_bubble_MILF_shows_off_for_me_My_Movie",
    "https://filemoon.to/e/d5j13kes06g3/Nice_outfit",
    "https://filemoon.to/e/ymro4dr5yjxp/NLC_Fair2023_16",
    "https://filemoon.to/e/vs19y1j22blu/NLC_Fair2023_17",
    "https://filemoon.to/e/j5wu22yw3mav/NLC_Fair2023_18",
    "https://filemoon.to/e/auqapuv6fxaz/NLC_Fair2023_19",
    "https://filemoon.to/e/4zgqlm4r6lof/NLC_Fair2023_20",
    "https://filemoon.to/e/eoj22175g08s/NLC_Fair2023_21",
    "https://filemoon.to/e/1oour82iv9oi/NLC_Fair2023_22",
    "https://filemoon.to/e/0tp8lnm9musl/NLC_Fair2023_23",
    "https://filemoon.to/e/6qq9hxcrnqrj/NLC_Fair2023_24",
    "https://filemoon.to/e/sw1em7c44agt/NLC_Pride2023_1",
    "https://filemoon.to/e/pjl419r6mc2b/NLC_Pride2023_10-1",
    "https://filemoon.to/e/lvak44j1h1q0/NLC_Pride2023_11",
    "https://filemoon.to/e/xjfq1qec6dqj/NLC_Pride2023_12",
    "https://filemoon.to/e/zd2m4canexbh/NLC_Pride2023_2",
    "https://filemoon.to/e/01echkx5quks/NLC_Pride2023_3",
    "https://filemoon.to/e/rd6niv7jrq67/NLC_Pride2023_4",
    "https://filemoon.to/e/v2wwlwb3qkoh/NLC_Pride2023_5",
    "https://filemoon.to/e/ekavjhq0b1v3/NLC_Pride2023_6",
    "https://filemoon.to/e/ehnr377rrdjl/NLC_Pride2023_7",
    "https://filemoon.to/e/h4e074kc7n1t/NLC_Pride2023_9",
    "https://filemoon.to/e/t29bltkowl4k/NotMe_TCZ_2023_-_Braless_girl_has_plenty_bounce",
    "https://filemoon.to/e/qiedx6ks590i/NotMe_TCZ_2023_-_These_girls_got_real_close_to_,my_camera",
    "https://filemoon.to/e/x5ftamsd862f/oldersis",
    "https://filemoon.to/e/ut0t2nwxnqr1/OOPP",
    "https://filemoon.to/e/flc3eipzhnh0/overkill",
    "https://filemoon.to/e/4hkbyfn82sv1/P87_LG_061_DryFitEbony",
    "https://filemoon.to/e/ana9i3aazu12/PAWG_booty_in_black_lulus",
    "https://filemoon.to/e/jql6uyjdzely/pawg_green_leggings_behind",
    "https://filemoon.to/e/ec2oe30q48qq/pawg_green_leggings_side",
    "https://filemoon.to/e/zinwj8ji09yq/pawg_green_leggings_touching_herself",
    "https://filemoon.to/e/pyz0gibx4plq/pawg_in_stripe_pants",
    "https://filemoon.to/e/jb0wt4gjv2s7/Pawg_nerdy_blonde_blue_shorts",
    "https://filemoon.to/e/yp60ltln7gvd/pawg_oshkosh2",
    "https://filemoon.to/e/cuf45wz1432a/Pawg",
    "https://filemoon.to/e/a9i5rat852zu/PAWGBootyCompilationVol_8",
    "https://filemoon.to/e/yoh3kfm1xee2/pawgmilfshopping",
    "https://filemoon.to/e/ht5cgvr0xp8j/pawgtarget",
    "https://filemoon.to/e/6lskbbv3l0h0/Pawgy_in_green_aeries-1080p60H",
    "https://filemoon.to/e/7es1my8veaqm/perfect_shape_booty",
    "https://filemoon.to/e/27kpokz0s2gw/PerfectGreenPawg",
    "https://filemoon.to/e/cvecgq4bymoq/perfectlittlepookies",
    "https://filemoon.to/e/way9e1gdzmps/Petit_Fit_Girl",
    "https://filemoon.to/e/bx53iocved7x/Phat_Booty_in_short_-1080p60H",
    "https://filemoon.to/e/wzaf2rr1jv2c/phat_latina_booties_2_mp4_version",
    "https://filemoon.to/e/vvn4mxy1jrsb/pink_gym_shark_fat_mound__1_",
    "https://filemoon.to/e/2pozyzipyyt3/Pink_hoodie_Milf_black_lulu-1080p60H",
    "https://filemoon.to/e/49ut7be1qy56/pinkhsleggings",
    "https://filemoon.to/e/d31aksa5epjy/PLUMP_ASS_BRUNETTE_LEANING_ASS_OUT_BRANDI",
    "https://filemoon.to/e/67k3wqj5o4lc/PlumpyAssEbonyGirlfriend",
    "https://filemoon.to/e/djyw10e1enqp/po12",
    "https://filemoon.to/e/lt0ngshqd4xn/polka_dot_thong_nerdy_teen_brunette_beauty_second_edit_2_",
    "https://filemoon.to/e/fzo1z3jojim7/powder_blue_dress_milf_in_grey_thong",
    "https://filemoon.to/e/lxsn6qk9wv7c/Pro_Diamond_-_4",
    "https://filemoon.to/e/14yzk7qr5ib2/Pro_Diamond_-_9",
    "https://filemoon.to/e/teg6xs0ibosf/Pro_Shorts_-_Uk_Wedgie_Jiggle",
    "https://filemoon.to/e/iz0o46h7s99l/Projekt_05-16_1__Full_HD_1080p_MEDIUM_FR30",
    "https://filemoon.to/e/bhd1pv92t4nh/Projekt_09-12_1__Full_HD_1080p_MEDIUM_FR60",
    "https://filemoon.to/e/bgs8no5n83iv/PureTeenCutieOnStrawBale",
    "https://filemoon.to/e/ag7z8t0va68r/purple",
    "https://filemoon.to/e/5ou8wpn3pss1/PurpleLeggingsPawg",
    "https://filemoon.to/e/5ml73fbm4rvw/Qtfairvpl",
    "https://filemoon.to/e/de8wu6jsgvhb/quick_big_ass",
    "https://filemoon.to/e/9v27vlreyfsq/RANDJ",
    "https://filemoon.to/e/m4cgi0e1ufsx/Rave_Booty_4K",
    "https://filemoon.to/e/5wxkhszrkx1e/REC20230904-172027-77__online-video-cutter_com_",
    "https://filemoon.to/e/itd49irn70zj/red_jiggle",
    "https://filemoon.to/e/jb5lzob8hr1g/RED_SHORTS_VPL_WHOLEFOODS_PAWG",
    "https://filemoon.to/e/tbzssfwx4zvn/red-haired_MILF_with_huge_butt_in_leggings_with_her_man",
    "https://filemoon.to/e/ksn7fvjukkfe/Redhead_And_Brunette_friends",
    "https://filemoon.to/e/uhqgfzqmjd17/rhpfct",
    "https://filemoon.to/e/blnd6rl37el6/Rutgers_Blackout__2023",
    "https://filemoon.to/e/t3fz3rhshfr6/screen-20230903-173559_2",
    "https://filemoon.to/e/ccw94uz5obbj/Scrumptious_Booty_in_joggers_-1080p60H",
    "https://filemoon.to/e/rsk9hicd7cxu/SEPHORA_ARITZA_DUO_CAP_LATINA",
    "https://filemoon.to/e/qn44oswa43hy/Sexy_lady_in_Camo_yoga_pants_-1080p60H",
    "https://filemoon.to/e/80df0w3q73ud/Sexy_teen_in_lulus_feeling_herself_up_My_Movie",
    "https://filemoon.to/e/awq6zfelk02d/Sexy_thick_Booty_in_nice_leggings_-1080p60H",
    "https://filemoon.to/e/hmolr9ltuetq/sexyblkmama",
    "https://filemoon.to/e/7vxyx487madw/sexyblonde",
    "https://filemoon.to/e/0octb3nlp3nm/Shapley_booty_in_yoga_pants_-1080p60H",
    "https://filemoon.to/e/do6py8mrfb42/she_dont_wear_nothing",
    "https://filemoon.to/e/h5h7u0fnncbx/she_loves_to_have_her_delicious_juicy_ass_followed",
    "https://filemoon.to/e/arf44bdkhgmc/shiny_tight_shorts",
    "https://filemoon.to/e/hs0nqs2m7p3w/short_very_short_and_tucked",
    "https://filemoon.to/e/fjb22dj7s160/short_yellow1",
    "https://filemoon.to/e/gq1i13tlqgp9/short",
    "https://filemoon.to/e/pwbcdgvubjzd/ShortHairMilfCheekASS",
    "https://filemoon.to/e/adu2n42b375h/SH_020",
    "https://filemoon.to/e/5d5dliqnuejs/silkdress",
    "https://filemoon.to/e/wrc2bppk40rv/Sleek_milf_in_flare_yoga_pants_-1080p60H",
    "https://filemoon.to/e/hu9obw74teci/SLIMPERVY_PINK_LEGGINGS_PAWG___GYM_Full_HD_1080p_HIGH_FR60",
    "https://filemoon.to/e/3o6u2r4zwvy1/SLUTTY_TOURIST",
    "https://filemoon.to/e/8l29gyseazme/Smack",
    "https://filemoon.to/e/at4tlv3ri4jx/small_elegant_milf_tits_in_a_bus_wtrk",
    "https://filemoon.to/e/uayt8jugpyrv/Such_a_thick_Booty_in_joggers_-1080p60H",
    "https://filemoon.to/e/u595fsvxv0un/summer",
    "https://filemoon.to/e/07774wtqe0y3/Super_Mini_Skirt_Anime_Cosplay_LLL",
    "https://filemoon.to/e/3tlh6mdghfd6/Super_skimpy_Thong",
    "https://filemoon.to/e/39n1l294j99g/Swedish_Pawg",
    "https://filemoon.to/e/y3at6efn7ork/sweetas",
    "https://filemoon.to/e/5i0gxt68jeg7/TallBrunetteSkinnyTeen",
    "https://filemoon.to/e/hq6v5tc1yjoa/Tattoo_phat_ass_milf-1080p60H",
    "https://filemoon.to/e/oa1xczdmxyh4/TCFeyegasm-QUKButtFloss",
    "https://filemoon.to/e/cdwcxc10u7ke/TCFeyegasm-QUKPronedBikiniTeenTutu",
    "https://filemoon.to/e/9jxj5zzq0zqx/TCFeyegasm-QUKTeenHottieShorts",
    "https://filemoon.to/e/ghrlb66rt72w/TCFeyegasm-TannedTattedSurfer",
    "https://filemoon.to/e/uob5gsv5nfya/TCFeyegasm-TeenCutiesBeachFun",
    "https://filemoon.to/e/yaz670rvzygb/TCFeyegasm-TeenJeanShortsVariety",
    "https://filemoon.to/e/t0eh6wft7x1y/Teen_grey_shorts_next_to_bf",
    "https://filemoon.to/e/vivvrk02l27t/Teen_with_a_cute_booty",
    "https://filemoon.to/e/6capxq26lqa3/Teen-in-simple-back-thong-1",
    "https://filemoon.to/e/c0jc3ebbr4o6/teenass",
    "https://filemoon.to/e/9wffw9jet448/TeenCutieCleavage",
    "https://filemoon.to/e/q0392ypv8uuj/TeenGotSweetBodyShapes",
    "https://filemoon.to/e/w3sufj28spim/TEVEOshorts",
    "https://filemoon.to/e/0chojoffvh99/THATA",
    "https://filemoon.to/e/o6khsumn6oac/thick_coloumbian_milf_with_green_nike_shirt",
    "https://filemoon.to/e/lemjxqe1fw0i/This_booty_is_unreal_in_black_yogas-1080p60H",
    "https://filemoon.to/e/em6n34on5d10/Tigeress",
    "https://filemoon.to/e/129fy0fo70bu/Tight_ass_black_jeans",
    "https://filemoon.to/e/md1g14aiz88n/tight_ebony",
    "https://filemoon.to/e/11l37w3ehtb1/Tight",
    "https://filemoon.to/e/tsu10vfi4th2/tightbubble",
    "https://filemoon.to/e/c57g6cz9jhwe/TightMilfHottie",
    "https://filemoon.to/e/38xjkarci87x/titlipts_wtrmk",
    "https://filemoon.to/e/gvcquy28cjmc/Tnaasian",
    "https://filemoon.to/e/pfnfy16btsf7/TnVPLPurpleshorts",
    "https://filemoon.to/e/ub05bowcpjuk/too_short",
    "https://filemoon.to/e/fkbu7n3y2uyn/TPs_lightskin_bikini_C0296_1",
    "https://filemoon.to/e/txoai2uvwpjs/Tremendously_plump_booty_in_blue_yoga_pants-1080p60H",
    "https://filemoon.to/e/g489o5o1a4zk/trim_48CFF819-2EAB-4AF8-B53D-F291188AFCEF_stabilized_909908E9",
    "https://filemoon.to/e/g2iglq03d16s/trim_79F8FED2-D377-43C9-8FC1-4E25E0D6117F_stabilized_3D92FD76",
    "https://filemoon.to/e/xqkky40bwdj2/trim_A72FE735-5E22-4A2B-A943-AFC91756B7AD_stabilized_50070127",
    "https://filemoon.to/e/h94vxckttfk1/trim_B5BBDF03-9DA3-4D2E-B97B-C6A79935E67D_stabilized_6A9D076C",
    "https://filemoon.to/e/fu4roqwmpevz/TrtrBASHI",
    "https://filemoon.to/e/01zz0fg9fbgr/TTDD",
    "https://filemoon.to/e/bmf6fjd1u3bt/turboblonde",
    "https://filemoon.to/e/85wbafovz6vl/Two_stunning_gals_-1080p60H",
    "https://filemoon.to/e/5xag0gkb73jh/TwoTeenCutiesPokies",
    "https://filemoon.to/e/6k7wkl5cb7da/TWOTJ",
    "https://filemoon.to/e/yv9jzsbp30oq/ultimatePhatButtMallTeebbty",
    "https://filemoon.to/e/rcpzh96emqzu/Unibreg4kP2",
    "https://filemoon.to/e/yl1d0gtmzswz/UnibregP1_4k",
    "https://filemoon.to/e/jl0f9hv56ol6/Untitled_1",
    "https://filemoon.to/e/dtuysc6nurav/Untitled_2",
    "https://filemoon.to/e/9q7jmpevlqj6/Untitled_5",
    "https://filemoon.to/e/fpbqotflpozu/Untitled_7_12",
    "https://filemoon.to/e/go0qz6mofst9/Untitled_2_",
    "https://filemoon.to/e/bano5w7a99qf/Upi_bus_sube",
    "https://filemoon.to/e/ewvptqbp9mik/Upi_Escaleras_Metro_logo",
    "https://filemoon.to/e/3i0nh4tmdkh0/Very_juicy_milf_ass_in_yoga_pants_-1080p60H",
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
