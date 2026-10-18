import * as esbuild from 'esbuild'
import { cpSync, mkdirSync, rmSync } from 'node:fs'

const serve = process.argv.includes('--serve')

rmSync('dist', { recursive: true, force: true })
mkdirSync('dist', { recursive: true })
cpSync('public', 'dist', { recursive: true })

const options = {
  entryPoints: ['src/main.jsx', 'src/styles.css'],
  bundle: true,
  minify: !serve,
  sourcemap: serve,
  format: 'esm',
  target: ['safari16'],
  jsx: 'automatic',
  jsxImportSource: 'preact',
  outdir: 'dist',
  entryNames: '[name]',
}

if (serve) {
  const ctx = await esbuild.context(options)
  await ctx.watch()
  const { port } = await ctx.serve({ servedir: 'dist', port: 5173 })
  console.log(`http://localhost:${port}`)
} else {
  await esbuild.build(options)
  console.log('built dist/')
}
