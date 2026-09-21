import pandas as pd
from faker import Faker
import random
from pathlib import Path
from datetime import timedelta

fake = Faker()
random.seed(42)
Faker.seed(42)

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

START = pd.Timestamp("2024-01-01")
END = pd.Timestamp("2026-12-31")
N_USERS = 100_000

COUNTRIES = ["United States","United Kingdom","Germany","France","Spain","Italy","Netherlands","Canada","Australia","Lithuania"]
DEVICES = ["iOS","Android","Web"]
CHANNELS = ["Organic","Google Ads","Facebook Ads","TikTok Ads","Referral","Email"]
CAMPAIGNS = {
    "Organic":["SEO","Direct"], "Google Ads":["Search_Generic","Search_Brand","Performance_Max"],
    "Facebook Ads":["Prospecting","Retargeting"], "TikTok Ads":["Video_Prospecting","Creator_Campaign"],
    "Referral":["Referral_Program"], "Email":["Lifecycle_Email","Reactivation"]
}
QUALITY = {"Organic":1.18,"Google Ads":1.00,"Facebook Ads":0.91,"TikTok Ads":0.78,"Referral":1.12,"Email":1.05}
PLANS = {"Monthly":12.99,"Quarterly":29.99,"Annual":89.99}

def rand_date(a, b):
    return a + timedelta(days=random.randint(0, max(0, (b-a).days)))

def users():
    rows=[]
    for uid in range(1,N_USERS+1):
        ch=random.choices(CHANNELS,weights=[25,22,18,12,13,10])[0]
        rows.append({
            "user_id":uid,"signup_date":rand_date(START,END).date(),
            "country":random.choices(COUNTRIES,weights=[24,13,12,10,8,7,6,7,5,8])[0],
            "age":random.randint(18,65),
            "gender":random.choices(["Female","Male","Other"],weights=[48,48,4])[0],
            "device_type":random.choices(DEVICES,weights=[42,48,10])[0],
            "acquisition_channel":ch,"campaign":random.choice(CAMPAIGNS[ch])
        })
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"users.csv",index=False); print(f"✓ users: {len(df):,}"); return df

def subscriptions(u):
    rows=[]; sid=1
    conv={"Organic":.34,"Google Ads":.29,"Facebook Ads":.24,"TikTok Ads":.20,"Referral":.32,"Email":.27}
    churn={"Monthly":.52,"Quarterly":.31,"Annual":.16}
    for _,x in u.iterrows():
        s=pd.Timestamp(x.signup_date)
        time_factor=min(1,(END-s).days/180)
        if random.random()>conv[x.acquisition_channel]*(.55+.45*time_factor): continue
        plan=random.choices(list(PLANS),weights=[58,25,17])[0]
        start=s+timedelta(days=random.randint(0,14))
        if start>END: continue
        cp=min(.9,max(.05,churn[plan]/QUALITY[x.acquisition_channel]*random.uniform(.75,1.25)))
        min_days={"Monthly":30,"Quarterly":90,"Annual":365}[plan]
        cancel=None; status="Active"
        if (END-start).days>min_days and random.random()<cp:
            cancel=start+timedelta(days=random.randint(min_days,(END-start).days))
            status="Cancelled"
        rows.append({"subscription_id":sid,"user_id":int(x.user_id),"plan_type":plan,
                     "start_date":start.date(),"status":status,
                     "cancel_date":cancel.date() if cancel else None,
                     "monthly_price":PLANS[plan],"trial_used":random.random()<.62})
        sid+=1
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"subscriptions.csv",index=False); print(f"✓ subscriptions: {len(df):,}"); return df

def payments(s):
    rows=[]; pid=1
    intervals={"Monthly":30,"Quarterly":90,"Annual":365}
    for _,x in s.iterrows():
        d=pd.Timestamp(x.start_date)
        end=pd.Timestamp(x.cancel_date) if pd.notna(x.cancel_date) else END
        while d<=end:
            ok=random.random()<.97
            rows.append({"payment_id":pid,"user_id":int(x.user_id),"subscription_id":int(x.subscription_id),
                         "payment_date":d.date(),"amount":x.monthly_price if ok else 0,
                         "payment_status":"Paid" if ok else "Failed"})
            pid+=1; d+=timedelta(days=intervals[x.plan_type])
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"payments.csv",index=False); print(f"✓ payments: {len(df):,}")

def sessions(u,s):
    sub_users=set(s.user_id.astype(int)); rows=[]; sid=1
    for _,x in u.iterrows():
        q=random.randint(12,45) if int(x.user_id) in sub_users else random.randint(2,15)
        q=max(1,int(q*QUALITY[x.acquisition_channel]*random.uniform(.85,1.15)))
        latest=min(END,pd.Timestamp(x.signup_date)+pd.Timedelta(days=730))
        for _ in range(q):
            d=rand_date(pd.Timestamp(x.signup_date),latest)
            rows.append({"session_id":sid,"user_id":int(x.user_id),"session_date":d.date(),
                         "duration_minutes":max(2,int(random.gauss(18*QUALITY[x.acquisition_channel],7))),
                         "platform":x.device_type})
            sid+=1
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"sessions.csv",index=False); print(f"✓ sessions: {len(df):,}"); return df

def events(u,sess,subs):
    sub_users=set(subs.user_id.astype(int)); rows=[]; eid=1
    user_map=u.set_index("user_id").to_dict("index")
    for _,x in sess.iterrows():
        uid=int(x.user_id); q=QUALITY[user_map[uid]["acquisition_channel"]]
        ev=["app_open"]
        if random.random()<min(.95,.55*q): ev+=["content_view"]
        if random.random()<min(.90,.45*q): ev+=["workout_start"]
        if "workout_start" in ev and random.random()<min(.85,.68*q): ev+=["workout_complete"]
        if random.random()<.08: ev+=["subscription_view"]
        if uid in sub_users and random.random()<.03: ev+=["subscription_purchase"]
        for e in ev:
            rows.append({"event_id":eid,"user_id":uid,"session_id":int(x.session_id),
                         "event_date":x.session_date,"event_type":e}); eid+=1
    for _,x in subs.iterrows():
        if pd.notna(x.cancel_date):
            rows.append({"event_id":eid,"user_id":int(x.user_id),"session_id":None,
                         "event_date":x.cancel_date,"event_type":"cancel_subscription"}); eid+=1
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"events.csv",index=False); print(f"✓ events: {len(df):,}")

def marketing():
    spend_range={"Google Ads":(1200,2200),"Facebook Ads":(800,1700),"TikTok Ads":(500,1300),
                 "Referral":(150,450),"Email":(100,300),"Organic":(50,150)}
    efficiency={"Google Ads":.75,"Facebook Ads":.65,"TikTok Ads":.55,"Referral":1.2,"Email":.95,"Organic":1.1}
    rows=[]; d=START
    while d<=END:
        for ch in CHANNELS:
            camp=random.choice(CAMPAIGNS[ch]); lo,hi=spend_range[ch]
            spend=round(random.uniform(lo,hi)*(.85 if d.dayofweek>=5 else 1),2)
            impressions=random.randint(8000,25000) if ch in ["Organic","Email"] else random.randint(20000,90000)
            clicks=random.randint(500,2500) if ch in ["Organic","Email"] else random.randint(500,5000)
            installs=max(1,int(spend*efficiency[ch]*random.uniform(.8,1.2)))
            rows.append({"date":d.date(),"channel":ch,"campaign":camp,"spend":spend,
                         "impressions":impressions,"clicks":clicks,"installs":installs})
        d+=timedelta(days=1)
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"marketing_spend.csv",index=False); print(f"✓ marketing_spend: {len(df):,}")

def experiments(u):
    sample=u.sample(n=30000,random_state=42); rows=[]
    for i,(_,x) in enumerate(sample.iterrows(),1):
        d=pd.Timestamp(x.signup_date)+pd.Timedelta(days=random.randint(0,3))
        rows.append({"experiment_id":i,"user_id":int(x.user_id),"experiment_name":"New Onboarding Flow",
                     "variant":random.choice(["Control","Variant_A"]),"assigned_date":d.date()})
    df=pd.DataFrame(rows); df.to_csv(DATA_DIR/"experiments.csv",index=False); print(f"✓ experiments: {len(df):,}")

if __name__=="__main__":
    print("\nGenerating FitFlow dataset...\n")
    u=users()
    s=subscriptions(u)
    payments(s)
    sess=sessions(u,s)
    events(u,sess,s)
    marketing()
    experiments(u)
    print("\n✓ Done. Files saved to data/")