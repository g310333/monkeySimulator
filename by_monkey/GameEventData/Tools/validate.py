#!/usr/bin/env python3
"""驗證本資料包 Schema 的有限關鍵字集合與跨檔契約；不是通用 JSON Schema 引擎。"""
import copy
import json
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def require(ok, message):
    if not ok: raise ValueError(message)

def check(value, schema, path='$'):
    if 'anyOf' in schema:
        errors=[]
        for child in schema['anyOf']:
            try: check(value,child,path); return
            except ValueError as error: errors.append(str(error))
        raise ValueError(path+': 不符合 anyOf')
    if 'const' in schema:
        require(type(value) is type(schema['const']) and value==schema['const'],path+': const 錯誤')
    if 'enum' in schema: require(value in schema['enum'],path+': enum 錯誤')
    t=schema.get('type')
    valid={'object':isinstance(value,dict),'array':isinstance(value,list),'string':isinstance(value,str),'boolean':type(value) is bool,'integer':type(value) is int,'number':type(value) in (int,float),'null':value is None}
    if t: require(valid[t],path+': 型別必須為 '+t)
    if t=='object':
        props=schema['properties']
        for key in schema.get('required',[]): require(key in value,path+': 缺少 '+key)
        if schema.get('additionalProperties') is False: require(not(set(value)-set(props)),path+': 未定義欄位 '+str(set(value)-set(props)))
        for key,v in value.items():
            if key in props: check(v,props[key],path+'.'+key)
    if t=='array':
        require(len(value)>=schema.get('minItems',0),path+': 陣列過短')
        require(len(value)<=schema.get('maxItems',float('inf')),path+': 陣列過長')
        if schema.get('uniqueItems'): require(len({json.dumps(v,sort_keys=True) for v in value})==len(value),path+': 重複項目')
        for i,v in enumerate(value):check(v,schema['items'],f'{path}[{i}]')
    if t=='string':
        require(len(value)>=schema.get('minLength',0),path+': 空字串')
        if 'pattern' in schema:require(re.search(schema['pattern'],value) is not None,path+': 格式錯誤')
    if t in ('number','integer'):
        require(value>=schema.get('minimum',-float('inf')),path+': 小於最小值')
        require(value<=schema.get('maximum',float('inf')),path+': 大於最大值')
        if 'exclusiveMinimum' in schema:require(value>schema['exclusiveMinimum'],path+': 未超過最小值')

def unique(items,key,label):
    ids=[x[key] for x in items];require(len(ids)==len(set(ids)),label+': 重複 '+key)

def event_check(event,characters):
    eid=event['id'];parts=set(event['participants'])
    require(parts<=characters,eid+': 未知角色')
    c=event['conditions']
    require(c.get('maximumDay') is None or c['maximumDay']>=c['minimumDay'],eid+': 天數上下限矛盾')
    require(c.get('maximumMoney') is None or c['maximumMoney']>=c['minimumMoney'],eid+': 金錢上下限矛盾')
    require(not(set(c['requiredFlags'])&set(c['excludedFlags'])),eid+': 旗標互斥')
    unique(event['dialogues'],'id',eid)
    for line in event['dialogues']:
        stage=line['stage'];visible={x['characterID'] for x in stage};slots={x['slot'] for x in stage}
        unique(stage,'characterID',eid);unique(stage,'slot',eid)
        require(visible<=parts,eid+': 在場角色不在 participants')
        require(line['speakerID'] in visible,eid+': 說話者不在舞台')
        expected={1:{'center'},2:{'left','right'},3:{'left','center','right'}}[len(stage)]
        require(slots==expected,eid+': 站位不符合人數')
        require('{' not in line['text'].replace('{playerName}','') and '}' not in line['text'].replace('{playerName}',''),eid+': 未支援文字替換')

def catalog_check(events,characters,check_prerequisites=True):
    unique(events,'id','events')
    for e in events:event_check(e,characters)
    if not check_prerequisites:return
    ids={e['id'] for e in events};graph={e['id']:e['conditions']['requiredCompletedEventIDs'] for e in events}
    for eid,requirements in graph.items():require(set(requirements)<=ids,eid+': 未知前置事件')
    visiting=set();done=set()
    def visit(eid):
        require(eid not in visiting,eid+': 前置事件循環')
        if eid in done:return
        visiting.add(eid)
        for dep in graph[eid]:visit(dep)
        visiting.remove(eid);done.add(eid)
    for eid in ids:visit(eid)

def save_check(save):
    unique(save['records'],'actionInstanceID','records');unique(save['records'],'settlementID','records');unique(save['history'],'eventID','history')
    completed={}
    triggered_id_list=[]
    for r in save['records']:
        status=r['status'];selected=r.get('selected');reason=r.get('noEventReason')
        if status=='pending':require(selected is None and reason is None,'pending 不可有判定結果')
        elif status=='no_event':require(selected is None and reason is not None,'no_event 必須有原因且不可有 selected')
        else:
            require(selected is not None and reason is None,status+': selected／原因錯誤')
            snap=selected['snapshot'];chars=snap['characters'];unique(chars,'id','snapshot characters')
            event=snap['event'];require({c['id'] for c in chars}==set(event['participants']),'快照角色不完整')
            event_check(event,{c['id'] for c in chars})
            require(event['trigger']['action']==r['context']['action'],'事件來源行動錯誤')
            require(selected['currentDialogueID'] in {d['id'] for d in event['dialogues']},'台詞游標不存在')
            triggered_id_list.append(event['id'])
            if status=='completed':
                require(selected['currentDialogueID']==event['dialogues'][-1]['id'],'完成游標不是最後句')
                completed.setdefault(event['id'],[]).append(r['actionInstanceID'])
    require(set(completed)=={h['eventID'] for h in save['history']},'history 與完成紀錄不一致')
    for h in save['history']:
        ids=completed[h['eventID']]
        require(h['completionCount']==len(ids),'完成次數不符')
        require(h['lastCompletedActionInstanceID'] in ids,'最後完成行動 ID 不符')
    # triggeredEventIDs 必須恰好等於全部已選取事件的集合。不要求 records 裡每個事件只
    # 出現一次：執行期（EventConditionEvaluator）已經確保「新」的判定不會再選到已觸發
    # 過的事件，但從舊版（repeatable）遷移過來的存檔可能本來就有好幾筆紀錄選到同一個
    # 曾經可重複的事件——那是要保留的既有進度，不是資料損壞。
    require(set(triggered_id_list)==set(save['triggeredEventIDs']),'triggeredEventIDs 與已選取事件不一致')

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def run():
    schemas={n:read(ROOT/f'Schemas/{n}.schema.json') for n in ['characters','events','rules','save']}
    chars=read(ROOT/'Resources/characters.json');events=read(ROOT/'Resources/events_work.json')
    check(chars,schemas['characters']);unique(chars['characters'],'id','characters')
    charids={c['id'] for c in chars['characters']}
    count=1
    for path in [ROOT/'Resources/events_work.json',ROOT/'Examples/event_template.json']:
        doc=read(path);check(doc,schemas['events']);catalog_check(doc['events'],charids);count+=1
    for path in [ROOT/'Resources/event_rules.json',ROOT/'Development/event_rules_debug.json']:
        doc=read(path);check(doc,schemas['rules']);unique(doc['rules'],'action','rules');count+=1
    for path in sorted((ROOT/'Examples').glob('save_*.json')):
        doc=read(path);check(doc,schemas['save']);save_check(doc);count+=1
    # 小型反例驗證：確認驗證器能阻擋影響載入、播放及去重的錯誤。
    tests=[]
    for label,mutation in [
        ('unknown speaker',lambda d:d['events'][0]['dialogues'][0].update(speakerID='missing')),
        ('duplicate event',lambda d:d['events'].append(copy.deepcopy(d['events'][0]))),
        ('day conflict',lambda d:d['events'][0]['conditions'].update(minimumDay=8,maximumDay=2)),
        ('cycle',lambda d:d['events'][0]['conditions'].update(requiredCompletedEventIDs=[d['events'][0]['id']])),
        ('unknown property',lambda d:d['events'][0].update(typo=True)),
        ('empty dialogues',lambda d:d['events'][0].update(dialogues=[])),
        ('duplicate slot',lambda d:d['events'][1]['dialogues'][0]['stage'][1].update(slot='left'))]:
        d=copy.deepcopy(events);mutation(d);tests.append((label,d,'events',lambda x:catalog_check(x['events'],charids)))
    d=read(ROOT/'Resources/event_rules.json');d['rules'][0]['eventChance']=1.5;tests.append(('chance range',d,'rules',lambda x:None))
    for label,mut in [
        ('missing selection',lambda d:d['records'][0].update(selected=None)),
        ('unknown cursor',lambda d:d['records'][0]['selected'].update(currentDialogueID='missing')),
        ('unsettled',lambda d:d['records'][0].update(settled=False)),
        ('duplicate action',lambda d:d['records'].append(copy.deepcopy(d['records'][0]))),
        ('triggeredEventIDs mismatch',lambda d:d.update(triggeredEventIDs=[])),
    ]:
        d=read(ROOT/'Examples/save_in_progress.json');mut(d);tests.append((label,d,'save',save_check))
    # 正例：從舊版（repeatable）遷移來的存檔可能有多筆紀錄選到同一個曾經可重複的事
    # 件——這是要保留的既有進度，triggeredEventIDs 仍應能通過驗證，不是反例。
    legit=read(ROOT/'Examples/save_in_progress.json')
    dup=copy.deepcopy(legit['records'][0])
    dup['actionInstanceID']='sample-work-action-002'
    dup['settlementID']='sample-settlement-002'
    legit['records'].append(dup)
    check(legit,schemas['save']);save_check(legit)
    for label,d,kind,extra in tests:
        try:check(d,schemas[kind]);extra(d)
        except ValueError:continue
        raise ValueError('反例未被攔截：'+label)
    print(f'PASS: {count} data files, {len(events["events"])} events, {len(tests)} invalid-data cases rejected.')
if __name__=='__main__':run()
