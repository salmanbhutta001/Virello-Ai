"""Seed: curated public communities by category.

All entries are real, public communities (subreddits, groups, boards).
Member counts are approximate (2026). Users discover these and share
manually — Virello never auto-posts.
"""

SEED_COMMUNITIES = [
    # ── Business & Entrepreneurship ──
    dict(platform="reddit", name="r/Entrepreneur", url="https://www.reddit.com/r/Entrepreneur/",
         category="business", topics="entrepreneur,startup,business,marketing,growth",
         description="Entrepreneurship discussion and advice", member_count=3500000),
    dict(platform="reddit", name="r/smallbusiness", url="https://www.reddit.com/r/smallbusiness/",
         category="business", topics="small business,local business,shop,store",
         description="Small business owners helping each other", member_count=1800000),
    dict(platform="reddit", name="r/startups", url="https://www.reddit.com/r/startups/",
         category="business", topics="startup,founders,funding,saas,tech startup",
         description="Startup founders and early-stage discussion", member_count=1400000),
    dict(platform="reddit", name="r/marketing", url="https://www.reddit.com/r/marketing/",
         category="business", topics="marketing,digital marketing,ads,branding,seo",
         description="Marketing strategy and tactics", member_count=1200000),

    # ── Fitness & Health ──
    dict(platform="reddit", name="r/fitness", url="https://www.reddit.com/r/fitness/",
         category="fitness", topics="fitness,workout,exercise,gym,training",
         description="General fitness discussion", member_count=12000000),
    dict(platform="reddit", name="r/loseit", url="https://www.reddit.com/r/loseit/",
         category="fitness", topics="weight loss,diet,health,transformation",
         description="Weight loss support community", member_count=4000000),
    dict(platform="reddit", name="r/HealthyFood", url="https://www.reddit.com/r/HealthyFood/",
         category="fitness", topics="healthy food,nutrition,recipes,meal prep,diet",
         description="Healthy eating and recipes", member_count=2500000),
    dict(platform="reddit", name="r/yoga", url="https://www.reddit.com/r/yoga/",
         category="fitness", topics="yoga,flexibility,meditation,wellness",
         description="Yoga practice and discussion", member_count=1800000),

    # ── Technology ──
    dict(platform="reddit", name="r/technology", url="https://www.reddit.com/r/technology/",
         category="tech", topics="technology,tech news,gadgets,innovation",
         description="Tech news and discussion", member_count=15000000),
    dict(platform="reddit", name="r/gadgets", url="https://www.reddit.com/r/gadgets/",
         category="tech", topics="gadgets,devices,electronics,reviews",
         description="Gadget news and reviews", member_count=2200000),
    dict(platform="reddit", name="r/artificial", url="https://www.reddit.com/r/artificial/",
         category="tech", topics="ai,artificial intelligence,machine learning,chatgpt",
         description="AI news and discussion", member_count=800000),
    dict(platform="reddit", name="r/learnprogramming", url="https://www.reddit.com/r/learnprogramming/",
         category="tech", topics="programming,coding,developer,software,learn code",
         description="Learning to program", member_count=5000000),

    # ── Food & Cooking ──
    dict(platform="reddit", name="r/food", url="https://www.reddit.com/r/food/",
         category="food", topics="food,cooking,recipes,meals",
         description="Food pictures and discussion", member_count=25000000),
    dict(platform="reddit", name="r/Cooking", url="https://www.reddit.com/r/Cooking/",
         category="food", topics="cooking,recipes,kitchen,chef,meals",
         description="Cooking tips and recipes", member_count=3500000),
    dict(platform="reddit", name="r/Baking", url="https://www.reddit.com/r/Baking/",
         category="food", topics="baking,cake,bread,dessert,pastry",
         description="Baking community", member_count=1800000),

    # ── Fashion & Beauty ──
    dict(platform="reddit", name="r/femalefashionadvice", url="https://www.reddit.com/r/femalefashionadvice/",
         category="fashion", topics="fashion,style,outfit,clothing,women fashion",
         description="Women's fashion advice", member_count=2200000),
    dict(platform="reddit", name="r/malefashionadvice", url="https://www.reddit.com/r/malefashionadvice/",
         category="fashion", topics="fashion,style,outfit,clothing,men fashion",
         description="Men's fashion advice", member_count=2800000),
    dict(platform="reddit", name="r/MakeupAddiction", url="https://www.reddit.com/r/MakeupAddiction/",
         category="fashion", topics="makeup,beauty,cosmetics,skincare",
         description="Makeup community", member_count=4500000),
    dict(platform="reddit", name="r/SkincareAddiction", url="https://www.reddit.com/r/SkincareAddiction/",
         category="fashion", topics="skincare,beauty,skin,cosmetics",
         description="Skincare science and routines", member_count=2200000),

    # ── Travel ──
    dict(platform="reddit", name="r/travel", url="https://www.reddit.com/r/travel/",
         category="travel", topics="travel,tourism,trip,vacation,adventure",
         description="Travel discussion and photos", member_count=10000000),
    dict(platform="reddit", name="r/solotravel", url="https://www.reddit.com/r/solotravel/",
         category="travel", topics="solo travel,backpacking,trip planning",
         description="Solo travel community", member_count=2800000),
    dict(platform="reddit", name="r/digitalnomad", url="https://www.reddit.com/r/digitalnomad/",
         category="travel", topics="digital nomad,remote work,travel work",
         description="Working remotely while traveling", member_count=2200000),

    # ── Finance ──
    dict(platform="reddit", name="r/personalfinance", url="https://www.reddit.com/r/personalfinance/",
         category="finance", topics="finance,money,saving,investing,budget",
         description="Personal finance advice", member_count=18000000),
    dict(platform="reddit", name="r/investing", url="https://www.reddit.com/r/investing/",
         category="finance", topics="investing,stocks,trading,finance",
         description="Investing discussion", member_count=2800000),
    dict(platform="reddit", name="r/CryptoCurrency", url="https://www.reddit.com/r/CryptoCurrency/",
         category="finance", topics="crypto,cryptocurrency,bitcoin,blockchain",
         description="Crypto news and discussion", member_count=8000000),

    # ── Education & Learning ──
    dict(platform="reddit", name="r/GetStudying", url="https://www.reddit.com/r/GetStudying/",
         category="education", topics="study,learning,students,exams,productivity",
         description="Study motivation and tips", member_count=1500000),
    dict(platform="reddit", name="r/languagelearning", url="https://www.reddit.com/r/languagelearning/",
         category="education", topics="language learning,english,urdu,spanish,french",
         description="Learning new languages", member_count=1800000),

    # ── Parenting & Family ──
    dict(platform="reddit", name="r/Parenting", url="https://www.reddit.com/r/Parenting/",
         category="parenting", topics="parenting,kids,children,family,mom,dad",
         description="Parenting support and advice", member_count=4500000),
    dict(platform="reddit", name="r/beyondthebump", url="https://www.reddit.com/r/beyondthebump/",
         category="parenting", topics="baby,newborn,motherhood,parenting",
         description="Parents of babies and toddlers", member_count=800000),

    # ── Home & DIY ──
    dict(platform="reddit", name="r/DIY", url="https://www.reddit.com/r/DIY/",
         category="home", topics="diy,home improvement,crafts,build",
         description="Do-it-yourself projects", member_count=25000000),
    dict(platform="reddit", name="r/HomeImprovement", url="https://www.reddit.com/r/HomeImprovement/",
         category="home", topics="home,renovation,repair,interior",
         description="Home improvement advice", member_count=3500000),
    dict(platform="reddit", name="r/InteriorDesign", url="https://www.reddit.com/r/InteriorDesign/",
         category="home", topics="interior design,decor,home decor,furniture",
         description="Interior design inspiration", member_count=2800000),

    # ── Gaming ──
    dict(platform="reddit", name="r/gaming", url="https://www.reddit.com/r/gaming/",
         category="gaming", topics="gaming,games,video games,pc gaming",
         description="Gaming discussion", member_count=40000000),
    dict(platform="reddit", name="r/pcmasterrace", url="https://www.reddit.com/r/pcmasterrace/",
         category="gaming", topics="pc gaming,computer,gaming setup",
         description="PC gaming community", member_count=8000000),

    # ── Photography & Art ──
    dict(platform="reddit", name="r/photography", url="https://www.reddit.com/r/photography/",
         category="art", topics="photography,photo,camera,portrait",
         description="Photography discussion", member_count=4500000),
    dict(platform="reddit", name="r/Art", url="https://www.reddit.com/r/Art/",
         category="art", topics="art,painting,drawing,artist",
         description="Art showcase and discussion", member_count=25000000),
    dict(platform="reddit", name="r/Design", url="https://www.reddit.com/r/Design/",
         category="art", topics="design,graphic design,ui,ux,creative",
         description="Design community", member_count=1200000),
]

CATEGORIES = [
    dict(id="business", name="Business", icon="business_center"),
    dict(id="fitness", name="Fitness & Health", icon="fitness_center"),
    dict(id="tech", name="Technology", icon="computer"),
    dict(id="food", name="Food & Cooking", icon="restaurant"),
    dict(id="fashion", name="Fashion & Beauty", icon="checkroom"),
    dict(id="travel", name="Travel", icon="flight"),
    dict(id="finance", name="Finance", icon="account_balance"),
    dict(id="education", name="Education", icon="school"),
    dict(id="parenting", name="Parenting", icon="child_care"),
    dict(id="home", name="Home & DIY", icon="home"),
    dict(id="gaming", name="Gaming", icon="sports_esports"),
    dict(id="art", name="Art & Design", icon="palette"),
]
