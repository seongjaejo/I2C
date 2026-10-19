"""Run the selected source checks with Icarus Verilog 13 (Python standard library)."""
from pathlib import Path
import argparse,subprocess,shutil,os,json,sys

HERE=Path(__file__).resolve().parent; ROOT=HERE.parent
p=argparse.ArgumentParser();p.add_argument('--tool-bin',type=Path);p.add_argument('--only');args=p.parse_args()
iverilog=str(args.tool_bin.resolve()/'iverilog.exe') if args.tool_bin else shutil.which('iverilog')
vvp=str(args.tool_bin.resolve()/'vvp.exe') if args.tool_bin else shutil.which('vvp')
if not iverilog or not vvp:sys.exit('Install Icarus Verilog 13 and add its bin to PATH, or pass --tool-bin PATH.')
env=os.environ.copy();env['PATH']=str(Path(iverilog).parent)+os.pathsep+env.get('PATH','')
ivl=Path(iverilog).resolve().parent.parent/'lib/ivl'
tests=json.loads((HERE/'tests.json').read_text());failures=[]
for t in tests:
    if args.only and t['name']!=args.only:continue
    d=HERE/'.build'/t['name'];d.mkdir(parents=True,exist_ok=True)
    for old in ('compile.txt','simulate.txt','sim.vvp'):
        if (d/old).exists():(d/old).unlink()
    sources=[x for pat in t['sources'] for x in sorted(ROOT.glob(pat))]+[ROOT/t['tb']]
    for asset in t['assets']:shutil.copy2(ROOT/asset,d/Path(asset).name)
    includes=sorted({str(f.parent) for f in sources})
    cmd=[iverilog,'-v','-g2012','-s',t['top'],'-o','sim.vvp']
    for inc in includes:cmd+=['-I',inc]
    cmd += [str(f) for f in sources]
    e=env.copy();e['IVERILOG_ICONFIG']=str(d/'compiler.conf')
    try:
        r=subprocess.run(cmd,cwd=d,env=e,capture_output=True,text=True,errors='replace',timeout=90)
        output=r.stdout+r.stderr;code=r.returncode
        # Certain sandboxed Windows shells crash in the driver's pipeline cleanup.
        # Preserve its exact configuration and execute the same compiler directly.
        if code==3221225477 and (d/'compiler.conf').exists() and (ivl/'ivl.exe').exists():
            shutil.copy2(d/'compiler.conf',d/'saved.conf')
            preenv=env.copy();preenv['IVERILOG_ICONFIG']=str(d/'pre.conf')
            pp=[iverilog,'-g2012','-E','-o','preprocessed.sv']
            for inc in includes:pp+=['-I',inc]
            pp += [str(f) for f in sources]
            r1=subprocess.run(pp,cwd=d,env=preenv,capture_output=True,text=True,errors='replace',timeout=60)
            r2=subprocess.run([str(ivl/'ivl.exe'),'-C'+str(d/'saved.conf'),'-C'+str(ivl/'vvp.conf'),'--',str(d/'preprocessed.sv')],cwd=d,env=env,capture_output=True,text=True,errors='replace',timeout=60)
            output+='\nDIRECT PIPELINE\n'+r1.stdout+r1.stderr+r2.stdout+r2.stderr
            code=r1.returncode or r2.returncode
        (d/'compile.txt').write_text(output,encoding='utf-8')
        if code:raise RuntimeError(f'compile code {code}')
        r=subprocess.run([vvp,'-n','sim.vvp'],cwd=d,env=env,capture_output=True,text=True,errors='replace',timeout=120)
        output=r.stdout+r.stderr;(d/'simulate.txt').write_text(output,encoding='utf-8')
        if r.returncode or 'FAIL' in output or t['pass_marker'] not in output:raise RuntimeError('simulation did not pass')
        print(t['name']+': PASS')
    except (RuntimeError,subprocess.TimeoutExpired) as ex:
        print(t['name']+': FAIL - '+str(ex));failures.append(t['name'])
if args.only and not any(t['name']==args.only for t in tests):sys.exit('Unknown --only test name')
sys.exit(1 if failures else 0)
