const MAP={
'CITY 经营权与原回执':'CITY 经营权与收据',
'Synthetic official\ncity':'城瘾官方 · 上海','Synthetic official city':'城瘾官方 · 上海',
'Synthetic cafe':'老麦咖啡馆',
'杭州市西湖区北山街':'上海市徐汇区武康路',
'Dongmen Night Market':'城隍庙夜市','Laojie Teahouse':'湖心亭茶楼','Binjiang Park Stage':'徐汇滨江舞台','Lane 9 Bookshop':'九弄书店',
'Old Town\nNight Walk bu...':'外滩钟声 · 老城寻踪三章','Old Town Night Walk bu…':'外滩钟声 · 老城寻踪三章',
'Lantern Gate (example)':'武康大楼',
'Night Walker':'夜行者',
'Lantern Gate Night Walker of the Old Quarter (example)':'武康路老城区的夜行者 · 六站全通',
'ROAM MEMORY':'漫游记忆',
'Game rw.quiz1794649681':'外滩快问快答','Game rw.quiz1794648716':'老城拼图','Game rw.quiz1794643512':'钟声节奏','E2E e2e.adm1.1794643461':'武康路寻宝',
'smoke-team-1f1c':'外滩钟声小队','E2E API smoke check':'周六下午一起走老城',
'手机号或微信号':'手机号','微信实付':'实付'};
const SUB=[[/城瘾官方\s*E2E/g,'城瘾官方'],[/ · E2E · NONE/g,' · 城瘾官方'],[/E2E · NONE/g,'城瘾官方'],[/北京时间 YYYY-MM-DD HH:mm/g,'选择日期和时间'],[/北京时间 YYYY-MM-DD/g,'选择日期'],[/smoke-team-[0-9a-f]+/g,'外滩钟声小队']];
