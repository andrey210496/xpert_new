import { motion } from 'framer-motion';

export function HeroSection() {
    return (
        <div className="flex flex-col items-center justify-center text-center px-4 py-6">
            <motion.h1
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5 }}
                className="text-3xl md:text-4xl lg:text-5xl font-extrabold tracking-tight leading-[1.1] font-display"
            >
                <span className="text-text-primary">Esclarecimento técnico</span>
                <br />
                <span className="text-text-primary">para decisões mais </span>
                <span className="text-accent">seguras</span>
            </motion.h1>

            <motion.p
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: 0.15 }}
                className="text-sm text-text-secondary max-w-md mx-auto mt-3 leading-relaxed"
            >
                Seu consultor preliminar para harmonizar a gestão, prevenir riscos e
                valorizar a convivência no condomínio.
            </motion.p>
        </div>
    );
}
