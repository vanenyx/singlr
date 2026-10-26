#pragma once
#include <QQuickItem>
#include <QElapsedTimer>
#include <QTimer>
#include <QPointer>
#include <QScreen>
#include <QHash>
#include <QtQml/qqmlregistration.h>

// A single immutable particle batch. Only uniforms change while animated.
class Singularity : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(bool animating READ animating NOTIFY animatingChanged)
    Q_PROPERTY(QPointF pointer READ pointer WRITE setPointer NOTIFY pointerChanged)
    Q_PROPERTY(bool reactive READ reactive WRITE setReactive NOTIFY reactiveChanged)
    Q_PROPERTY(int quality READ quality WRITE setQuality NOTIFY qualityChanged)
    Q_PROPERTY(qreal elapsed READ elapsed NOTIFY elapsedChanged)
public:
    explicit Singularity(QQuickItem *parent = nullptr);
    bool running() const { return m_running; }
    bool animating() const { return m_timer.isActive(); }
    QPointF pointer() const { return m_target; }
    bool reactive() const { return m_reactive; }
    int quality() const { return m_quality; }
    qreal elapsed() const { return m_time; }
    void setRunning(bool value);
    void setPointer(QPointF value);
    void setReactive(bool value);
    void setQuality(int value);
signals:
    void runningChanged();
    void animatingChanged();
    void pointerChanged();
    void reactiveChanged();
    void qualityChanged();
    void elapsedChanged();
protected:
    QSGNode *updatePaintNode(QSGNode *, UpdatePaintNodeData *) override;
    bool eventFilter(QObject *, QEvent *) override;
private slots:
    void setLocked(bool value);
    void setSleeping(bool value);
private:
    void syncTimer();
    void attachWindow(QQuickWindow *window);
    QTimer m_timer;
    QElapsedTimer m_clock;
    QPointer<QQuickWindow> m_window;
    QHash<QScreen *, bool> m_screenOff;
    QPointF m_target{.5, .5}, m_pointer{.5, .5};
    qreal m_time = 0;
    bool m_running = false, m_reactive = true, m_locked = false, m_sleeping = false;
    int m_quality = 1;
};
