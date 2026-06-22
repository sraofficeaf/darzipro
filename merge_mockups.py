import re
import os

mobile_path = r"c:\Users\user\Desktop\Projects\darzi_pro\darzi_pro\darzi_pro_premium.html"
desktop_path = r"c:\Users\user\Desktop\Projects\darzi_pro\darzi_pro\darzi_pro_desktop_premium.html"
output_path = r"c:\Users\user\Desktop\Projects\darzi_pro\darzi_pro\darzi_pro_complete.html"

def prefix_css(css_text, prefix, body_class):
    # First, strip all CSS comments to prevent them from interfering with selector matching
    css_text = re.sub(r'/\*.*?\*/', '', css_text, flags=re.DOTALL)
    
    # Split by rules, keeping track of nested braces (for @media blocks)
    rules = []
    current_rule = []
    brace_count = 0
    
    for char in css_text:
        current_rule.append(char)
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
            if brace_count == 0:
                rules.append("".join(current_rule))
                current_rule = []
                
    if current_rule:
        rules.append("".join(current_rule))
        
    prefixed_rules = []
    
    for rule in rules:
        rule = rule.strip()
        if not rule:
            continue
            
        # Check if it's @media or @keyframes
        if rule.startswith('@media') or rule.startswith('@keyframes') or rule.startswith('@-webkit-keyframes'):
            match = re.match(r'^(@[^{]+)\{(.*)\}$', rule, re.DOTALL)
            if match:
                at_header = match.group(1).strip()
                inner_css = match.group(2).strip()
                if 'keyframes' in at_header:
                    prefixed_rules.append(rule)
                else:
                    inner_prefixed = prefix_css(inner_css, prefix, body_class)
                    prefixed_rules.append(f"{at_header} {{\n{inner_prefixed}\n}}")
            else:
                prefixed_rules.append(rule)
            continue
            
        match = re.match(r'^([^{]+)\{(.*)\}$', rule, re.DOTALL)
        if not match:
            prefixed_rules.append(rule)
            continue
            
        selectors_part = match.group(1).strip()
        properties_part = match.group(2).strip()
        
        selectors = [s.strip() for s in selectors_part.split(',') if s.strip()]
        prefixed_selectors = []
        
        for selector in selectors:
            # Control bar elements should remain global
            is_control = False
            for ctrl_class in ['.ctrl', '.theme-tog', '.view-tog', '.th-btn', '.th-b', '.ctrl-screen', '.ctrl-scr', '.ctrl-logo']:
                if selector.startswith(ctrl_class) or f" {ctrl_class}" in selector:
                    is_control = True
                    break
                    
            if is_control:
                prefixed_selectors.append(selector)
            elif selector == ':root':
                prefixed_selectors.append(f"{body_class}")
            elif selector == '[data-theme="light"]' or selector == '[data-theme=\'light\']':
                prefixed_selectors.append(f"[data-theme=\"light\"] {body_class}")
            elif selector == 'body':
                prefixed_selectors.append(f"{body_class}")
            elif selector == 'html':
                prefixed_selectors.append("html")
            elif selector.startswith('body '):
                prefixed_selectors.append(selector.replace('body ', f"{body_class} "))
            elif selector.startswith('[data-theme="light"] body') or selector.startswith('[data-theme=\'light\'] body'):
                prefixed_selectors.append(selector.replace('body', body_class))
            elif selector.startswith('html '):
                prefixed_selectors.append(selector)
            else:
                prefixed_selectors.append(f"{prefix} {selector}")
                
        prefixed_rules.append(f"{', '.join(prefixed_selectors)} {{\n  {properties_part}\n}}")
        
    return "\n".join(prefixed_rules)

def extract_style_and_body(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Find style block
    style_match = re.search(r'<style>(.*?)</style>', content, re.DOTALL)
    style_content = style_match.group(1) if style_match else ""
    
    # Find body block
    body_match = re.search(r'<body>(.*?)</body>', content, re.DOTALL)
    body_content = body_match.group(1) if body_match else ""
    
    # Remove script tags from body content (we will write our own unified script)
    body_content_clean = re.sub(r'<script>.*?</script>', '', body_content, flags=re.DOTALL)
    
    # Remove ctrl bar from body content (we will write a unified controls bar)
    body_content_clean = re.sub(r'<div class="ctrl">.*?</div>', '', body_content_clean, flags=re.DOTALL)
    
    return style_content, body_content_clean

def main():
    print("Reading mobile HTML...")
    mobile_style, mobile_body = extract_style_and_body(mobile_path)
    
    print("Reading desktop HTML...")
    desktop_style, desktop_body = extract_style_and_body(desktop_path)
    
    print("Prefixing CSS rules...")
    prefixed_mobile_style = prefix_css(mobile_style, ".mobile-layout", "body.view-phone")
    prefixed_desktop_style = prefix_css(desktop_style, ".desktop-layout", "body.view-desktop")
    
    print("Building unified HTML...")
    
    html = f"""<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Darzi Pro — Premium Responsive Mockup</title>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Inter:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
/* ════════════════════════════════════════
   GLOBAL STYLE overrides / view switcher
   ════════════════════════════════════════ */
body {{
  font-family: 'Inter', sans-serif;
  min-height: 100vh;
  margin: 0;
  padding: 0;
  overflow-x: hidden;
  transition: background .3s, color .3s;
}}

/* Global controls bar styling (floatingDynamic capsule) */
.ctrl {{
  position: fixed;
  top: 10px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1000;
  display: flex;
  align-items: center;
  gap: 12px;
  background: rgba(5,9,15,.75);
  backdrop-filter: blur(24px);
  border: 1px solid rgba(255,255,255,.07);
  border-radius: 30px;
  padding: 6px 18px;
  box-shadow: 0 4px 20px rgba(0,0,0,.4);
  transition: all .3s;
}}
[data-theme="light"] .ctrl {{
  background: rgba(234,240,255,.85);
  border-color: rgba(0,0,0,.08);
  box-shadow: 0 4px 16px rgba(15,22,35,.08);
}}
.ctrl-logo {{
  font-family: 'Outfit', sans-serif;
  font-size: 14px;
  font-weight: 900;
  color: var(--a, #F5A623);
  letter-spacing: .3px;
  padding-right: 12px;
  border-right: 1px solid rgba(255,255,255,.1);
}}
[data-theme="light"] .ctrl-logo {{
  border-right-color: rgba(0,0,0,.1);
}}
.theme-tog, .view-tog {{
  display: flex;
  background: rgba(255,255,255,.055);
  border: 1px solid rgba(255,255,255,.07);
  border-radius: 20px;
  padding: 3px;
  gap: 2px;
}}
[data-theme="light"] .theme-tog, [data-theme="light"] .view-tog {{
  background: rgba(0,0,0,.04);
  border-color: rgba(0,0,0,.06);
}}
.th-btn, .th-b {{
  padding: 4px 13px;
  border-radius: 16px;
  font-size: 11.5px;
  font-weight: 700;
  background: none;
  border: none;
  color: #5A7090;
  transition: all .2s;
  cursor: pointer;
}}
.th-btn.on, .th-b.on {{
  background: linear-gradient(135deg, #F5A623, #D4791A);
  color: #1a0e00;
  box-shadow: 0 2px 10px rgba(245,166,35,.3);
}}
.ctrl-screen, .ctrl-scr {{
  font-size: 11.5px;
  font-weight: 600;
  color: #5A7090;
  padding-left: 10px;
  border-left: 1px solid rgba(255,255,255,.1);
}}
[data-theme="light"] .ctrl-screen, [data-theme="light"] .ctrl-scr {{
  border-left-color: rgba(0,0,0,.1);
}}

/* Layout containers toggles */
.desktop-layout, .mobile-layout {{
  display: none;
  width: 100%;
}}

body.view-desktop .desktop-layout {{
  display: block;
}}

body.view-phone .mobile-layout {{
  display: flex;
  justify-content: center;
  align-items: flex-start;
  min-height: calc(100vh - 64px);
  padding: 20px 0;
}}

/* Ensure phone container centers properly inside mobile-layout */
body.view-phone .phone {{
  margin: 0 auto;
}}

/* Responsive behavior overrides for real mobile screens (<= 768px) */
@media (max-width: 768px) {{
  /* Hide desktop and mockup borders */
  .view-tog {{
    display: none !important;
  }}
  .desktop-layout {{
    display: none !important;
  }}
  body.view-phone .mobile-layout, body.view-desktop .mobile-layout {{
    display: block !important;
    padding: 0 !important;
    min-height: 100vh !important;
  }}
  .mobile-layout .phone {{
    width: 100% !important;
    height: 100vh !important;
    max-height: none !important;
    border-radius: 0 !important;
    box-shadow: none !important;
    border: none !important;
  }}
  .mobile-layout .phone-border-decorations,
  .mobile-layout .di,
  .mobile-layout .phone-btns-l,
  .mobile-layout .phone-btns-r,
  .mobile-layout .sbar {{
    display: none !important;
  }}
  .mobile-layout .scr {{
    padding-bottom: 90px !important; /* spacing for bottom nav */
  }}
}}

/* ════════════════════════════════════════
   MOBILE PREMIUM CSS (PREPARED & SCOPED)
   ════════════════════════════════════════ */
{prefixed_mobile_style}

/* ════════════════════════════════════════
   DESKTOP PREMIUM CSS (PREPARED & SCOPED)
   ════════════════════════════════════════ */
{prefixed_desktop_style}
</style>
</head>
<body class="view-desktop">

<!-- GLOBAL CONTROLS BAR -->
<div class="ctrl">
  <div class="ctrl-logo">✂ DARZI PRO</div>
  
  <div class="view-tog">
    <button class="th-b on" id="btn-desktop" onclick="setView('desktop')">🖥 Desktop</button>
    <button class="th-b" id="btn-phone" onclick="setView('phone')">📱 Mobile</button>
  </div>
  
  <div class="theme-tog">
    <button class="th-b on" id="btn-dark" onclick="setTheme('dark')">🌙 Dark</button>
    <button class="th-b" id="btn-light" onclick="setTheme('light')">☀️ Light</button>
  </div>
  
  <div class="ctrl-scr" id="ctrl-scr">Dashboard</div>
</div>

<!-- ════════════════ DESKTOP LAYOUT ════════════════ -->
<div class="desktop-layout">
  {desktop_body}
</div>

<!-- ════════════════ MOBILE LAYOUT ════════════════ -->
<div class="mobile-layout">
  {mobile_body}
</div>

<script>
// Consolidated Javascript logic for both viewports
const desktopTitles = {{
  dashboard: 'Dashboard',
  clients: 'Clients',
  orders: 'Order Pipeline',
  measurements: 'Measurements',
  token: 'Customer Card',
  reports: 'Reports & Analytics',
  settings: 'Settings & Profile'
}};

const mobileNames = {{
  splash: 'Splash',
  login: 'Login',
  home: 'Dashboard',
  clients: 'Clients',
  'client-detail': 'Client Detail',
  orders: 'Orders',
  'order-detail': 'Order Detail',
  measurements: 'Measurements',
  token: 'Token Card',
  reports: 'Reports',
  profile: 'Profile'
}};

const screenMap = {{
  // mobile -> desktop
  'splash': 'dashboard',
  'login': 'dashboard',
  'home': 'dashboard',
  'clients': 'clients',
  'client-detail': 'clients',
  'orders': 'orders',
  'order-detail': 'orders',
  'measurements': 'measurements',
  'token': 'token',
  'reports': 'reports',
  'profile': 'settings',
  
  // desktop -> mobile
  'dashboard': 'home',
  'settings': 'profile'
}};

let mobileStack = ['splash'];

function navigateTo(id) {{
  // If it's a mobile screen key
  if (mobileNames[id] !== undefined) {{
    const from = mobileStack[mobileStack.length - 1];
    if (from === id) return;
    
    const fe = document.querySelector('.mobile-layout #s-' + from);
    const te = document.querySelector('.mobile-layout #s-' + id);
    if (te) {{
      if (fe) {{
        fe.classList.remove('active');
        fe.classList.add('back');
        setTimeout(() => {{
          fe.classList.remove('back');
          fe.classList.add('inactive');
        }}, 320);
      }}
      te.classList.remove('inactive', 'back');
      void te.offsetWidth;
      te.classList.add('active');
      te.scrollTo(0, 0);
      mobileStack.push(id);
      
      updateMobileUI(id);
    }}
    
    // Sync to Desktop screen
    const desktopId = screenMap[id] || id;
    activateDesktopScreen(desktopId);
  }} 
  // If it's a desktop screen key
  else if (desktopTitles[id] !== undefined) {{
    activateDesktopScreen(id);
    
    // Sync to Mobile screen
    const mobileId = screenMap[id] || id;
    activateMobileScreenDirect(mobileId);
  }}
}}

// Aliases for backwards compatibility with inline templates' onclick handlers
function go(id) {{
  navigateTo(id);
}}

function goBack() {{
  if (mobileStack.length <= 1) return;
  const cur = mobileStack.pop();
  const prev = mobileStack[mobileStack.length - 1];
  
  const ce = document.querySelector('.mobile-layout #s-' + cur);
  const pe = document.querySelector('.mobile-layout #s-' + prev);
  if (ce) {{
    ce.classList.remove('active');
    ce.classList.add('inactive');
  }}
  if (pe) {{
    pe.classList.remove('inactive', 'back');
    pe.classList.add('active');
    pe.scrollTo(0, 0);
  }}
  updateMobileUI(prev);
  
  // Sync to desktop
  const desktopId = screenMap[prev] || prev;
  activateDesktopScreen(desktopId);
}}

function goTab(id) {{
  const cur = mobileStack[mobileStack.length - 1];
  if (cur === id) return;
  
  const ce = document.querySelector('.mobile-layout #s-' + cur);
  const ne = document.querySelector('.mobile-layout #s-' + id);
  if (ce) {{
    ce.classList.remove('active');
    ce.classList.add('inactive');
  }}
  if (ne) {{
    ne.classList.remove('inactive', 'back');
    ne.classList.add('active');
    ne.scrollTo(0, 0);
  }}
  mobileStack = [id];
  updateMobileUI(id);
  
  // Sync to desktop
  const desktopId = screenMap[id] || id;
  activateDesktopScreen(desktopId);
}}

function activateMobileScreenDirect(id) {{
  document.querySelectorAll('.mobile-layout .scr').forEach(s => {{
    s.classList.remove('active', 'back');
    s.classList.add('inactive');
  }});
  const te = document.querySelector('.mobile-layout #s-' + id);
  if (te) {{
    te.classList.remove('inactive');
    te.classList.add('active');
  }}
  mobileStack = [id];
  updateMobileUI(id);
}}

function activateDesktopScreen(id) {{
  document.querySelectorAll('.desktop-layout .screen').forEach(s => {{
    s.classList.remove('active');
  }});
  const s = document.querySelector('.desktop-layout #s-' + id);
  if (s) {{
    s.classList.add('active');
  }}
  
  // Update desktop sidebar highlighting
  document.querySelectorAll('.desktop-layout .sb-nav a').forEach(a => {{
    a.classList.remove('on');
  }});
  const sn = document.querySelector('.desktop-layout #sn-' + id);
  if (sn) {{
    sn.classList.add('on');
  }}
  
  // Update desktop topbar title
  const t = document.querySelector('.desktop-layout #tb-title');
  if (t) {{
    t.textContent = desktopTitles[id] || id;
  }}
  
  // Update active screen indicator in controls
  const activeLabel = document.getElementById('ctrl-scr');
  if (activeLabel) {{
    activeLabel.textContent = desktopTitles[id] || mobileNames[id] || id;
  }}
  
  const contentArea = document.querySelector('.desktop-layout .content');
  if (contentArea) {{
    contentArea.scrollTo(0, 0);
  }}
}}

function updateMobileUI(id) {{
  // Mobile bottom nav active state
  document.querySelectorAll('.mobile-layout .bni').forEach(b => {{
    b.classList.remove('on');
  }});
  const bn = document.querySelector('.mobile-layout #bn-' + id);
  if (bn) {{
    bn.classList.add('on');
  }}
  
  // Mobile header & bottom nav visibility
  const isAuth = id === 'splash' || id === 'login';
  const ahdr = document.querySelector('.mobile-layout #ahdr');
  const bnav = document.querySelector('.mobile-layout #bnav');
  if (ahdr) ahdr.style.display = isAuth ? 'none' : 'flex';
  if (bnav) bnav.style.display = isAuth ? 'none' : 'flex';
  
  const subs = {{
    home: 'SaifurRahman Tailors',
    clients: 'All Clients',
    orders: 'Pipeline',
    reports: 'Analytics',
    profile: 'Settings & Profile'
  }};
  const hdrSub = document.querySelector('.mobile-layout #hdr-sub');
  if (hdrSub && subs[id]) {{
    hdrSub.textContent = subs[id];
  }}
  
  // Update active screen indicator in controls
  const activeLabel = document.getElementById('ctrl-scr');
  if (activeLabel) {{
    activeLabel.textContent = mobileNames[id] || desktopTitles[id] || id;
  }}
}}

function setTheme(t) {{
  document.documentElement.setAttribute('data-theme', t);
  document.querySelectorAll('#btn-dark').forEach(b => b.classList.toggle('on', t === 'dark'));
  document.querySelectorAll('#btn-light').forEach(b => b.classList.toggle('on', t === 'light'));
}}

function setView(v) {{
  document.querySelectorAll('#btn-phone').forEach(b => b.classList.toggle('on', v === 'phone'));
  document.querySelectorAll('#btn-desktop').forEach(b => b.classList.toggle('on', v === 'desktop'));
  
  if (v === 'phone') {{
    document.body.classList.remove('view-desktop');
    document.body.classList.add('view-phone');
  }} else {{
    document.body.classList.remove('view-phone');
    document.body.classList.add('view-desktop');
  }}
}}

function checkViewport() {{
  if (window.innerWidth <= 768) {{
    document.body.classList.remove('view-desktop');
    document.body.classList.add('view-phone');
    const viewTog = document.querySelector('.view-tog');
    if (viewTog) viewTog.style.display = 'none';
  }} else {{
    const viewTog = document.querySelector('.view-tog');
    if (viewTog) viewTog.style.display = 'flex';
    if (document.body.classList.contains('view-phone')) {{
      setView('phone');
    }} else {{
      setView('desktop');
    }}
  }}
}}

// Initialize
window.addEventListener('resize', checkViewport);
window.addEventListener('DOMContentLoaded', () => {{
  checkViewport();
  
  // Initialize screens
  activateMobileScreenDirect('splash');
  activateDesktopScreen('dashboard');
  
  // Set theme from body attr or default dark
  const theme = document.documentElement.getAttribute('data-theme') || 'dark';
  setTheme(theme);
}});

// Interactive behaviors binding
// Mobile
document.querySelectorAll('.mobile-layout .la-btn').forEach(b=>b.onclick=function(){{
  document.querySelectorAll('.mobile-layout .la-btn').forEach(x=>x.classList.remove('on'));
  this.classList.add('on');
}});
document.querySelectorAll('.mobile-layout .fch').forEach(c=>c.onclick=function(){{
  this.closest('.fchips').querySelectorAll('.fch').forEach(x=>x.classList.remove('on'));
  this.classList.add('on');
}});
document.querySelectorAll('.mobile-layout .tab').forEach(t=>t.onclick=function(){{
  this.closest('.tabs').querySelectorAll('.tab').forEach(x=>x.classList.remove('on'));
  this.classList.add('on');
}});

// Desktop
document.querySelectorAll('.desktop-layout .tab').forEach(t=>t.onclick=function(){{
  this.parentElement.querySelectorAll('.tab').forEach(x=>x.classList.remove('on'));
  this.classList.add('on');
}});
document.querySelectorAll('.desktop-layout .cat-btn').forEach(c=>c.onclick=function(){{
  document.querySelectorAll('.desktop-layout .cat-btn').forEach(x=>x.classList.remove('on'));
  this.classList.add('on');
}});

// Splash screen dots animation
let sdi=0;
setInterval(()=>{{
  const dots=document.querySelectorAll('.mobile-layout .sp-dot');
  if (dots.length > 0) {{
    dots.forEach(d=>d.classList.remove('on'));
    sdi=(sdi+1)%3;
    for(let i=0;i<=sdi;i++)dots[i].classList.add('on');
  }}
}},750);
</script>
</body>
</html>
"""

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html)
        
    print("Done! responsive UI saved to", output_path)

if __name__ == "__main__":
    main()
